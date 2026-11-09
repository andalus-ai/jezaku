package tech.kayys.jezaku.presence;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

class HttpPresenceAudienceAccessClient {
    private static final int DEFAULT_REQUEST_TIMEOUT_SECONDS = 3;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper;
    private final Optional<String> socialBaseUrl;
    private final int requestTimeoutSeconds;

    HttpPresenceAudienceAccessClient(
            ObjectMapper objectMapper,
            Optional<String> socialBaseUrl,
            int requestTimeoutSeconds) {
        this.objectMapper = objectMapper;
        this.socialBaseUrl = socialBaseUrl == null ? Optional.empty() : socialBaseUrl;
        this.requestTimeoutSeconds = requestTimeoutSeconds;
    }

    PresenceAudienceAccessResponse access(PresenceAudienceAccessRequest request) {
        if (request.viewerId().isBlank()) {
            return new LocalPresenceAudienceAccessClient().access(request);
        }
        List<PresenceAudienceAccessDecision> decisions = new ArrayList<>();
        for (var entry : ownersByScope(request).entrySet()) {
            decisions.addAll(fetchScope(request.viewerId(), entry.getKey(), entry.getValue()));
        }
        return new PresenceAudienceAccessResponse(request.viewerId(), "social", false, decisions);
    }

    URI audienceAccessUri() {
        String baseUrl = socialBaseUrl
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("Social service base URL is not configured"));
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return URI.create(normalized + "/social/audience/access");
    }

    String requestJson(String viewerId, String scope, List<PresenceAudienceOwner> owners) {
        try {
            return objectMapper.writeValueAsString(new SocialAudienceAccessRequest(
                    viewerId,
                    scope,
                    "",
                    owners.stream()
                            .map(PresenceAudienceOwner::ownerId)
                            .distinct()
                            .toList()));
        } catch (IOException exception) {
            throw new UncheckedIOException("Social audience access request could not be serialized", exception);
        }
    }

    PresenceAudienceAccessResponse responseFromJson(String json, String viewerId) {
        try {
            SocialAudienceAccessResponse response = objectMapper.readValue(json, SocialAudienceAccessResponse.class);
            List<PresenceAudienceAccessDecision> decisions = response.decisions() == null
                    ? fallbackDecisions(response)
                    : response.decisions().stream()
                            .map(decision -> new PresenceAudienceAccessDecision(
                                    decision.ownerId(),
                                    decision.canView(),
                                    decision.reason()))
                            .toList();
            return new PresenceAudienceAccessResponse(viewerId, "social", false, decisions);
        } catch (IOException exception) {
            throw new UncheckedIOException("Social audience access response could not be parsed", exception);
        }
    }

    Duration requestTimeout() {
        int normalizedSeconds = requestTimeoutSeconds <= 0
                ? DEFAULT_REQUEST_TIMEOUT_SECONDS
                : requestTimeoutSeconds;
        return Duration.ofSeconds(normalizedSeconds);
    }

    private List<PresenceAudienceAccessDecision> fetchScope(
            String viewerId,
            String scope,
            List<PresenceAudienceOwner> owners) {
        HttpRequest httpRequest = HttpRequest.newBuilder(audienceAccessUri())
                .timeout(requestTimeout())
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestJson(viewerId, scope, owners)))
                .build();
        try {
            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            return responseFromJson(successfulBody(response), viewerId).decisions();
        } catch (IOException exception) {
            throw new UncheckedIOException("Social audience access request failed", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Social audience access request was interrupted", exception);
        }
    }

    private Map<String, List<PresenceAudienceOwner>> ownersByScope(PresenceAudienceAccessRequest request) {
        return request.owners().stream()
                .collect(Collectors.groupingBy(owner -> scope(owner.visibility())));
    }

    private String scope(String visibility) {
        if ("friends".equals(visibility)) {
            return "friends";
        }
        if ("private".equals(visibility)) {
            return "private";
        }
        return "public";
    }

    private List<PresenceAudienceAccessDecision> fallbackDecisions(SocialAudienceAccessResponse response) {
        List<PresenceAudienceAccessDecision> decisions = new ArrayList<>();
        if (response.allowedOwnerIds() != null) {
            response.allowedOwnerIds().stream()
                    .map(ownerId -> PresenceAudienceAccessDecision.allow(ownerId, PresenceVisibilityPolicy.REASON_VISIBLE))
                    .forEach(decisions::add);
        }
        if (response.deniedOwnerIds() != null) {
            response.deniedOwnerIds().stream()
                    .map(ownerId -> PresenceAudienceAccessDecision.deny(
                            ownerId,
                            PresenceVisibilityPolicy.REASON_VISIBILITY_HIDDEN))
                    .forEach(decisions::add);
        }
        return decisions;
    }

    private String successfulBody(HttpResponse<String> response) {
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("Social audience access request failed with status " + response.statusCode());
        }
        return response.body();
    }

    private record SocialAudienceAccessRequest(
            String viewerId,
            String scope,
            String targetId,
            List<String> ownerIds) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record SocialAudienceAccessResponse(
            List<String> allowedOwnerIds,
            List<String> deniedOwnerIds,
            List<SocialAudienceDecision> decisions) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record SocialAudienceDecision(
            String ownerId,
            boolean canView,
            String reason) {
    }
}
