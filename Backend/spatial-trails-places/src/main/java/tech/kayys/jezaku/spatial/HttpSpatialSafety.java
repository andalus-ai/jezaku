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
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;
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

    @Override
    public RouteEvaluation evaluateRoutes(List<RouteCandidate> routes, double corridorBufferMeters) {
        validateRouteCandidates(routes, corridorBufferMeters);
        if (!enforced) {
            Instant now = Instant.now();
            Instant validUntil = now.plusSeconds(15);
            return new RouteEvaluation("local-unenforced", now, validUntil,
                    routes.stream().map(route -> new RouteDecision(route.routeId(), "ALLOWED",
                            List.of(), "LOCAL_ENFORCEMENT_DISABLED", List.of(), true, validUntil)).toList());
        }
        try {
            List<RouteRequest> routeRequests = routes.stream()
                    .map(route -> new RouteRequest(route.routeId(), route.points().stream()
                            .map(point -> new RoutePoint(point.latitude(), point.longitude())).toList()))
                    .toList();
            String body = json.writeValueAsString(Map.of(
                    "corridorBufferMeters", corridorBufferMeters,
                    "routes", routeRequests));
            HttpResponse<String> response = http.send(
                    ServiceTokenSource.request(routeEvaluationUri())
                            .timeout(timeout)
                            .header("content-type", "application/json")
                            .POST(HttpRequest.BodyPublishers.ofString(body))
                            .build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw unavailable("Spatial route safety evaluation failed with status " + response.statusCode(), null);
            }
            JsonNode payload = json.readTree(response.body());
            String snapshotId = payload.path("policySnapshotId").asText("");
            Instant evaluatedAt = parseInstant(payload.path("evaluatedAt").asText(""));
            Instant validUntil = parseInstant(payload.path("validUntil").asText(""));
            JsonNode revisionNode = payload.path("policyRevision");
            JsonNode results = payload.path("results");
            if (snapshotId.isBlank() || evaluatedAt == null || validUntil == null
                    || !revisionNode.canConvertToLong() || revisionNode.asLong() < 0
                    || !validUntil.isAfter(evaluatedAt) || validUntil.isAfter(evaluatedAt.plusSeconds(15))
                    || !results.isArray() || results.size() != routes.size()) {
                throw unavailable("Spatial safety service returned an incomplete route assessment", null);
            }
            List<RouteDecision> decisions = new ArrayList<>(results.size());
            for (int index = 0; index < results.size(); index++) {
                JsonNode result = results.get(index);
                RouteCandidate candidate = routes.get(index);
                String routeId = result.path("routeId").asText("");
                String outcome = result.path("outcome").asText("");
                String reasonCode = result.path("reasonCode").asText("");
                JsonNode restrictions = result.path("restrictionIds");
                JsonNode segments = result.path("affectedSegmentIndices");
                JsonNode permits = result.path("permitsOperation");
                Instant routeValidUntil = parseInstant(result.path("validUntil").asText(""));
                if (!candidate.routeId().equals(routeId) || !OUTCOMES.contains(outcome)
                        || reasonCode.isBlank() || !restrictions.isArray() || !segments.isArray()
                        || !permits.isBoolean() || routeValidUntil == null
                        || routeValidUntil.isBefore(validUntil) || routeValidUntil.isAfter(evaluatedAt.plusSeconds(15))) {
                    throw unavailable("Spatial safety service returned an invalid route decision", null);
                }
                boolean expectedPermits = "ALLOWED".equals(outcome) || "CAUTION".equals(outcome);
                if (permits.asBoolean() != expectedPermits) {
                    throw unavailable("Spatial safety service returned an inconsistent route outcome", null);
                }
                List<String> restrictionIds = new ArrayList<>();
                for (JsonNode restriction : restrictions) {
                    if (!restriction.isTextual() || restriction.asText().isBlank()) {
                        throw unavailable("Spatial safety service returned invalid restriction references", null);
                    }
                    restrictionIds.add(restriction.asText());
                }
                List<Integer> affectedSegments = new ArrayList<>();
                for (JsonNode segment : segments) {
                    if (!segment.canConvertToInt() || segment.asInt() < 0
                            || segment.asInt() >= candidate.points().size() - 1) {
                        throw unavailable("Spatial safety service returned invalid segment references", null);
                    }
                    affectedSegments.add(segment.asInt());
                }
                decisions.add(new RouteDecision(routeId, outcome, restrictionIds, reasonCode,
                        affectedSegments, permits.asBoolean(), routeValidUntil));
            }
            return new RouteEvaluation(snapshotId, evaluatedAt, validUntil, decisions, revisionNode.asLong());
        } catch (WebApplicationException exception) {
            throw exception;
        } catch (IOException exception) {
            throw unavailable("Spatial route safety response could not be read", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw unavailable("Spatial route safety evaluation was interrupted", exception);
        } catch (RuntimeException exception) {
            throw unavailable("Spatial route safety evaluation is unavailable", exception);
        }
    }

    URI routeEvaluationUri() {
        String base = safetyBaseUrl.map(String::trim).filter(value -> !value.isEmpty())
                .orElseThrow(() -> unavailable("jezaku.spatial.safety.base-url is not configured", null));
        String normalized = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        return URI.create(normalized + "/safety/spatial/evaluate/routes");
    }

    private void validateRouteCandidates(List<RouteCandidate> routes, double corridorBufferMeters) {
        if (routes == null || routes.isEmpty() || routes.size() > 5
                || !Double.isFinite(corridorBufferMeters) || corridorBufferMeters < 0 || corridorBufferMeters > 500) {
            throw unavailable("Route candidates or corridor buffer are outside supported bounds", null);
        }
        Set<String> ids = new HashSet<>();
        int totalVertices = 0;
        for (RouteCandidate route : routes) {
            if (route == null || route.routeId() == null || route.routeId().isBlank()
                    || route.routeId().length() > 64 || !ids.add(route.routeId())
                    || route.points() == null || route.points().size() < 2 || route.points().size() > 2_000) {
                throw unavailable("Route candidate is malformed or exceeds supported bounds", null);
            }
            totalVertices += route.points().size();
            if (totalVertices > 5_000 || route.points().stream().anyMatch(java.util.Objects::isNull)) {
                throw unavailable("Route batch exceeds supported geometry bounds", null);
            }
            for (GeoPoint point : route.points()) {
                if (!Double.isFinite(point.latitude()) || point.latitude() < -90 || point.latitude() > 90
                        || !Double.isFinite(point.longitude()) || point.longitude() < -180 || point.longitude() > 180) {
                    throw unavailable("Route coordinates are outside WGS84 bounds", null);
                }
            }
        }
    }

    private Instant parseInstant(String value) {
        try {
            return value == null || value.isBlank() ? null : Instant.parse(value);
        } catch (RuntimeException exception) {
            return null;
        }
    }

    private record RouteRequest(String routeId, List<RoutePoint> points) { }
    private record RoutePoint(double latitude, double longitude) { }

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
