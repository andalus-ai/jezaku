package tech.kayys.jezaku.discovery;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Singleton;
import jakarta.ws.rs.WebApplicationException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.ServiceTokenSource;
import tech.kayys.jezaku.discovery.DiscoveryDtos.GeoPoint;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Calls the Safety service once per bounded discovery candidate batch; never fails open. */
@Singleton
class HttpDiscoverySpatialSafety implements DiscoverySpatialSafety {
    private static final int MAX_BATCH_SIZE = 500;
    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final boolean enforced;
    private final Optional<String> safetyBaseUrl;
    private final Duration timeout;

    HttpDiscoverySpatialSafety(
            @ConfigProperty(name = "jezaku.discovery.spatial-safety.enforced", defaultValue = "true") boolean enforced,
            @ConfigProperty(name = "jezaku.discovery.spatial-safety.base-url") Optional<String> safetyBaseUrl,
            @ConfigProperty(name = "jezaku.discovery.request-timeout-seconds", defaultValue = "3") int timeoutSeconds) {
        this.enforced = enforced;
        this.safetyBaseUrl = safetyBaseUrl;
        this.timeout = Duration.ofSeconds(Math.max(1, timeoutSeconds));
    }

    @Override
    public List<String> evaluate(List<GeoPoint> positions) {
        if (positions == null) {
            throw unavailable("Discovery candidates are required for spatial safety evaluation", null);
        }
        if (positions.isEmpty()) {
            return List.of();
        }
        if (positions.size() > MAX_BATCH_SIZE) {
            throw unavailable("Discovery candidate batch exceeds the spatial safety limit", null);
        }
        if (!enforced) {
            return positions.stream().map(ignored -> "ALLOWED").toList();
        }
        if (positions.stream().anyMatch(java.util.Objects::isNull)) {
            throw unavailable("A discovery candidate has no authoritative position", null);
        }
        try {
            List<EvaluationRequest> requests = positions.stream()
                    .map(point -> new EvaluationRequest(point.latitude(), point.longitude(), "DISCOVER"))
                    .toList();
            String body = json.writeValueAsString(Map.of("requests", requests));
            HttpResponse<String> response = http.send(
                    ServiceTokenSource.request(evaluationUri())
                            .timeout(timeout)
                            .header("content-type", "application/json")
                            .POST(HttpRequest.BodyPublishers.ofString(body))
                            .build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw unavailable("Spatial safety batch evaluation failed with status " + response.statusCode(), null);
            }
            JsonNode results = json.readTree(response.body()).path("results");
            if (!results.isArray() || results.size() != positions.size()) {
                throw unavailable("Spatial safety service returned an incomplete batch result", null);
            }
            java.util.ArrayList<String> outcomes = new java.util.ArrayList<>(results.size());
            for (JsonNode result : results) {
                String outcome = result.path("decision").path("outcome").asText("");
                if (outcome.isBlank()) {
                    throw unavailable("Spatial safety service returned an invalid decision", null);
                }
                outcomes.add(outcome);
            }
            return List.copyOf(outcomes);
        } catch (WebApplicationException exception) {
            throw exception;
        } catch (IOException exception) {
            throw unavailable("Spatial safety response could not be read", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw unavailable("Spatial safety evaluation was interrupted", exception);
        } catch (RuntimeException exception) {
            throw unavailable("Spatial safety evaluation is unavailable", exception);
        }
    }

    URI evaluationUri() {
        String base = safetyBaseUrl.map(String::trim).filter(value -> !value.isEmpty())
                .orElseThrow(() -> unavailable("jezaku.discovery.spatial-safety.base-url is not configured", null));
        String normalized = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        return URI.create(normalized + "/safety/spatial/evaluate/batch");
    }

    private WebApplicationException unavailable(String message, Throwable cause) {
        return cause == null
                ? new WebApplicationException(message, 503)
                : new WebApplicationException(message, cause, 503);
    }

    private record EvaluationRequest(double latitude, double longitude, String activity) {
    }
}
