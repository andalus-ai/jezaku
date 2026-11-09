package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.CompletionException;

/**
 * Delegates memory owner visibility checks to the social audience service.
 */
class HttpCameraMemoryVisibilityClient {
    private static final int DEFAULT_REQUEST_TIMEOUT_SECONDS = 3;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper;
    private final Optional<String> socialBaseUrl;
    private final String scope;
    private final String targetId;
    private final int requestTimeoutSeconds;

    HttpCameraMemoryVisibilityClient(
            ObjectMapper objectMapper,
            Optional<String> socialBaseUrl,
            String scope,
            String targetId,
            int requestTimeoutSeconds) {
        this.objectMapper = objectMapper;
        this.socialBaseUrl = socialBaseUrl == null ? Optional.empty() : socialBaseUrl;
        this.scope = scope == null || scope.isBlank() ? "public" : scope.trim();
        this.targetId = targetId == null ? "" : targetId.trim();
        this.requestTimeoutSeconds = requestTimeoutSeconds;
    }

    Uni<CameraMemoryVisibilityResult> filter(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayResponse response) {
        if (response.dots().isEmpty()) {
            return Uni.createFrom().item(CameraMemoryVisibilityReports.result(
                    response,
                    List.of(),
                    "social_audience",
                    "social",
                    "healthy",
                    false));
        }
        HttpRequest httpRequest;
        try {
            httpRequest = HttpRequest.newBuilder(socialAudienceAccessUri())
                    .timeout(requestTimeout())
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json(request, response)))
                    .build();
        } catch (RuntimeException exception) {
            return Uni.createFrom().failure(exception);
        }
        return Uni.createFrom().completionStage(() -> httpClient
                .sendAsync(httpRequest, HttpResponse.BodyHandlers.ofString())
                .thenApply(this::successfulBody)
                .thenApply(json -> filterFromJson(response, json)));
    }

    URI socialAudienceAccessUri() {
        String baseUrl = socialBaseUrl
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("Social service base URL is not configured"));
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return URI.create(normalized + "/social/audience/access");
    }

    CameraMemoryVisibilityResult filterFromJson(CameraMemoryOverlayResponse response, String json) {
        try {
            SocialAudienceAccessResponse access = objectMapper.readValue(json, SocialAudienceAccessResponse.class);
            Set<String> allowedOwnerIds = allowedOwnerIds(access);
            Map<String, String> hiddenReasonsByOwner = hiddenReasonsByOwner(access);
            List<CameraMemoryVisibilityReports.Candidate> candidates = response.dots().stream()
                    .map(dot -> socialCandidate(dot, allowedOwnerIds, hiddenReasonsByOwner))
                    .toList();
            return CameraMemoryVisibilityReports.result(
                    response,
                    candidates,
                    "social_audience",
                    audienceSource(access),
                    audienceHealth(access),
                    audienceFallback(access));
        } catch (IOException exception) {
            throw new UncheckedIOException("Social audience access response could not be parsed", exception);
        }
    }

    String json(CameraMemoryOverlayRequest request, CameraMemoryOverlayResponse response) {
        try {
            return objectMapper.writeValueAsString(new SocialAudienceAccessRequest(
                    request.viewerId(),
                    scope,
                    targetId,
                    ownerIds(response)));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Social audience access payload could not be serialized", exception);
        }
    }

    private List<String> ownerIds(CameraMemoryOverlayResponse response) {
        return response.dots().stream()
                .map(CameraMemoryOverlayDot::ownerId)
                .filter(ownerId -> ownerId != null && !ownerId.isBlank())
                .distinct()
                .toList();
    }

    private CameraMemoryVisibilityReports.Candidate socialCandidate(
            CameraMemoryOverlayDot dot,
            Set<String> allowedOwnerIds,
            Map<String, String> hiddenReasonsByOwner) {
        if (allowedOwnerIds.contains(dot.ownerId())) {
            return CameraMemoryVisibilityReports.visible(dot);
        }
        return CameraMemoryVisibilityReports.hidden(dot, hiddenReason(dot, hiddenReasonsByOwner));
    }

    private String hiddenReason(
            CameraMemoryOverlayDot dot,
            Map<String, String> hiddenReasonsByOwner) {
        String ownerId = dot.ownerId();
        String reason = hiddenReasonsByOwner.get(ownerId);
        if (reason != null && !reason.isBlank()) {
            return reason;
        }
        return ownerId == null || ownerId.isBlank() ? "visibility_hidden" : "denied";
    }

    private Set<String> allowedOwnerIds(SocialAudienceAccessResponse access) {
        Set<String> allowedOwnerIds = new LinkedHashSet<>(emptyIfNull(access.allowedOwnerIds()));
        emptyIfNull(access.decisions()).stream()
                .filter(decision -> Boolean.TRUE.equals(decision.allowed()))
                .map(SocialAudienceAccessDecision::ownerId)
                .filter(ownerId -> ownerId != null && !ownerId.isBlank())
                .forEach(allowedOwnerIds::add);
        return allowedOwnerIds;
    }

    private Map<String, String> hiddenReasonsByOwner(SocialAudienceAccessResponse access) {
        Map<String, String> reasons = new LinkedHashMap<>();
        emptyIfNull(access.deniedOwnerIds()).stream()
                .filter(ownerId -> ownerId != null && !ownerId.isBlank())
                .forEach(ownerId -> reasons.put(ownerId, "denied"));
        emptyIfNull(access.decisions()).stream()
                .filter(decision -> Boolean.FALSE.equals(decision.allowed()))
                .filter(decision -> decision.ownerId() != null && !decision.ownerId().isBlank())
                .forEach(decision -> reasons.put(
                        decision.ownerId(),
                        CameraMemoryVisibilityReports.visibilityReason(decision.reason())));
        return reasons;
    }

    private String audienceSource(SocialAudienceAccessResponse access) {
        return access.audienceSource() == null || access.audienceSource().isBlank()
                ? "social"
                : access.audienceSource().trim();
    }

    private String audienceHealth(SocialAudienceAccessResponse access) {
        if (access.audienceHealth() == null || access.audienceHealth().isBlank()) {
            return audienceFallback(access) ? "degraded" : "healthy";
        }
        return access.audienceHealth();
    }

    private boolean audienceFallback(SocialAudienceAccessResponse access) {
        return Boolean.TRUE.equals(access.audienceFallback());
    }

    private String successfulBody(HttpResponse<String> response) {
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new CompletionException(new IllegalStateException(
                    "Social audience access request failed with status " + response.statusCode()));
        }
        return response.body();
    }

    Duration requestTimeout() {
        int normalizedSeconds = requestTimeoutSeconds <= 0
                ? DEFAULT_REQUEST_TIMEOUT_SECONDS
                : requestTimeoutSeconds;
        return Duration.ofSeconds(normalizedSeconds);
    }

    private <T> List<T> emptyIfNull(List<T> values) {
        return values == null ? List.of() : values;
    }

    private record SocialAudienceAccessRequest(
            String viewerId,
            String scope,
            String targetId,
            List<String> ownerIds) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record SocialAudienceAccessResponse(
            String audienceSource,
            String audienceHealth,
            Boolean audienceFallback,
            List<String> allowedOwnerIds,
            List<String> deniedOwnerIds,
            List<SocialAudienceAccessDecision> decisions) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record SocialAudienceAccessDecision(
            String ownerId,
            Boolean allowed,
            String reason) {
    }
}
