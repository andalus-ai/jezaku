package tech.kayys.jezaku.memory;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.inject.Singleton;
import jakarta.ws.rs.WebApplicationException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.auth.ServiceTokenSource;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Optional;

/**
 * Calls the Safety service rather than depending on another service's implementation classes.
 * A missing endpoint, failed request, or malformed response is a denial (503), never an allow.
 */
@Singleton
class HttpMemorySpatialSafety implements MemorySpatialSafety {
    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final boolean enforced;
    private final Optional<String> safetyBaseUrl;
    private final Duration timeout;

    HttpMemorySpatialSafety(
            @ConfigProperty(name = "jezaku.memory.spatial-safety.enforced", defaultValue = "true") boolean enforced,
            @ConfigProperty(name = "jezaku.memory.spatial-safety.base-url") Optional<String> safetyBaseUrl,
            @ConfigProperty(name = "jezaku.memory.request-timeout-seconds", defaultValue = "3") int timeoutSeconds) {
        this.enforced = enforced;
        this.safetyBaseUrl = safetyBaseUrl;
        this.timeout = Duration.ofSeconds(Math.max(1, timeoutSeconds));
    }

    @Override
    public void requirePublishPermitted(GeoPoint position) {
        if (!enforced) {
            return;
        }
        if (position == null) {
            throw unavailable("A placement position is required for spatial safety evaluation", null);
        }
        try {
            String body = json.writeValueAsString(new EvaluationRequest(
                    position.latitude(), position.longitude(), "PUBLISH"));
            HttpResponse<String> response = http.send(
                    ServiceTokenSource.request(evaluationUri())
                            .timeout(timeout)
                            .header("content-type", "application/json")
                            .POST(HttpRequest.BodyPublishers.ofString(body))
                            .build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw unavailable("Spatial safety evaluation failed with status " + response.statusCode(), null);
            }
            JsonNode decision = json.readTree(response.body()).path("decision");
            String outcome = decision.path("outcome").asText("");
            if (outcome.isBlank()) {
                throw unavailable("Spatial safety service returned no decision", null);
            }
            if (!"ALLOWED".equals(outcome) && !"CAUTION".equals(outcome)) {
                throw new WebApplicationException(
                        "AR frame placement denied by spatial safety policy: "
                                + decision.path("reasonCode").asText("SPATIAL_POLICY_DENIED"),
                        403);
            }
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
                .orElseThrow(() -> unavailable("jezaku.memory.spatial-safety.base-url is not configured", null));
        String normalized = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        return URI.create(normalized + "/safety/spatial/evaluate");
    }

    private WebApplicationException unavailable(String message, Throwable cause) {
        return cause == null
                ? new WebApplicationException(message, 503)
                : new WebApplicationException(message, cause, 503);
    }

    private record EvaluationRequest(double latitude, double longitude, String activity) {
    }
}
