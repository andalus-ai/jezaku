package tech.kayys.jezaku.engagement;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Singleton;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.ServiceTokenSource;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Reads friendships from the social service's internal {@code POST /social/relationships/context/batch}. */
@Singleton
class HttpFrameRelationships implements FrameRelationships {
    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final Optional<String> socialBaseUrl;
    private final Duration timeout;

    HttpFrameRelationships(
            @ConfigProperty(name = "jezaku.engagement.social-base-url") Optional<String> socialBaseUrl,
            @ConfigProperty(name = "jezaku.engagement.request-timeout-seconds", defaultValue = "3") int timeoutSeconds) {
        this.socialBaseUrl = socialBaseUrl;
        this.timeout = Duration.ofSeconds(Math.max(1, timeoutSeconds));
    }

    URI batchUri() {
        String base = socialBaseUrl.map(String::trim).filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("jezaku.engagement.social-base-url is not configured"));
        String normalized = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        return URI.create(normalized + "/social/relationships/context/batch");
    }

    String requestJson(String viewerId, Collection<String> otherIds) throws IOException {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("viewerId", viewerId);
        body.put("ownerIds", List.copyOf(otherIds));
        return json.writeValueAsString(body);
    }

    @Override
    public Map<String, FrameRelationship> relationships(String viewerId, Collection<String> otherIds) {
        if (otherIds.isEmpty()) {
            return Map.of();
        }
        try {
            HttpResponse<String> response = http.send(
                    ServiceTokenSource.request(batchUri())
                            .timeout(timeout)
                            .header("content-type", "application/json")
                            .POST(HttpRequest.BodyPublishers.ofString(requestJson(viewerId, otherIds)))
                            .build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Relationship lookup failed with status " + response.statusCode());
            }
            return fromJson(response.body());
        } catch (IOException e) {
            throw new IllegalStateException("Relationship lookup failed", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Relationship lookup interrupted", e);
        }
    }

    Map<String, FrameRelationship> fromJson(String body) throws IOException {
        Map<String, FrameRelationship> result = new HashMap<>();
        for (JsonNode context : json.readTree(body).path("contexts")) {
            String ownerId = context.path("ownerId").asText("");
            if (!ownerId.isBlank()) {
                result.put(ownerId, new FrameRelationship(
                        context.path("blocked").asBoolean(false),
                        context.path("directFriend").asBoolean(false)));
            }
        }
        return result;
    }
}
