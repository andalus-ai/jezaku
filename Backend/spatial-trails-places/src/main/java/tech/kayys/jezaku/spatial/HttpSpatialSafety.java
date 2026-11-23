package tech.kayys.jezaku.spatial;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Singleton;
import jakarta.ws.rs.WebApplicationException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.ServiceTokenSource;
import tech.kayys.jezaku.spatial.SpatialDtos.GeoPoint;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Service-authenticated, bounded adapter to the central Safety policy API. */
@Singleton
class HttpSpatialSafety implements SpatialSafety {
    private static final int MAX_BATCH_SIZE = 500;
    private static final List<String> OUTCOMES =
            List.of("ALLOWED", "CAUTION", "RESTRICTED", "PROHIBITED", "EMERGENCY_LOCKDOWN");

    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final boolean enforced;
    private final Optional<String> safetyBaseUrl;
    private final Duration timeout;

    HttpSpatialSafety(
            @ConfigProperty(name = "jezaku.spatial.safety.enforced", defaultValue = "true") boolean enforced,
            @ConfigProperty(name = "jezaku.spatial.safety.base-url") Optional<String> safetyBaseUrl,
            @ConfigProperty(name = "jezaku.spatial.request-timeout-seconds", defaultValue = "3") int timeoutSeconds) {
        this.enforced = enforced;
        this.safetyBaseUrl = safetyBaseUrl;
        this.timeout = Duration.ofSeconds(Math.max(1, timeoutSeconds));
    }

    @Override
    public void requirePublishPermitted(GeoPoint position) {
        List<String> decisions = evaluate("PUBLISH", List.of(position));
        if (!"ALLOWED".equals(decisions.get(0)) && !"CAUTION".equals(decisions.get(0))) {
            throw new WebApplicationException("Spatial anchor publication denied by safety policy", 403);
        }
    }

    @Override
    public List<String> evaluate(String activity, List<GeoPoint> positions) {
        if (positions == null || positions.size() > MAX_BATCH_SIZE
                || positions.stream().anyMatch(java.util.Objects::isNull)) {
            throw unavailable("Spatial candidates are missing or exceed the safety batch limit", null);
        }
        if (positions.isEmpty()) {
            return List.of();
        }
        if (!List.of("DISCOVER", "RENDER", "PUBLISH").contains(activity)) {
            throw unavailable("Unsupported spatial safety activity", null);
        }
        if (!enforced) {
            return positions.stream().map(ignored -> "ALLOWED").toList();
        }
        try {
            List<EvaluationRequest> requests = positions.stream()
                    .map(point -> new EvaluationRequest(point.latitude(), point.longitude(), activity))
                    .toList();
            String body = json.writeValueAsString(Map.of("requests", requests));
            HttpResponse<String> response = http.send(
                    ServiceTokenSource.request(batchEvaluationUri())
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
                throw unavailable("Spatial safety service returned an incomplete decision batch", null);
            }
            java.util.ArrayList<String> outcomes = new java.util.ArrayList<>(results.size());
            for (JsonNode result : results) {
                String outcome = result.path("decision").path("outcome").asText("");
                if (!OUTCOMES.contains(outcome)) {
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

    URI batchEvaluationUri() {
        String base = safetyBaseUrl.map(String::trim).filter(value -> !value.isEmpty())
                .orElseThrow(() -> unavailable("jezaku.spatial.safety.base-url is not configured", null));
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
