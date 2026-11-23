package tech.kayys.jezaku.spatial;

import jakarta.ws.rs.WebApplicationException;
import tech.kayys.jezaku.spatial.SpatialDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

/** Spatial policy boundary owned by the Safety service. */
public interface SpatialSafety {
    void requirePublishPermitted(GeoPoint position);

    List<String> evaluate(String activity, List<GeoPoint> positions);

    /**
     * Evaluate provider-generated route alternatives. Implementations must fail closed
     * unless they explicitly provide an unenforced dev/test policy.
     */
    default RouteEvaluation evaluateRoutes(List<RouteCandidate> routes, double corridorBufferMeters) {
        throw new WebApplicationException("Route safety evaluation is unavailable", 503);
    }

    static SpatialSafety allowAll() {
        return new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                return positions.stream().map(ignored -> "ALLOWED").toList();
            }

            @Override
            public RouteEvaluation evaluateRoutes(List<RouteCandidate> routes, double corridorBufferMeters) {
                Instant now = Instant.now();
                Instant validUntil = now.plusSeconds(15);
                return new RouteEvaluation("local-unenforced", now, validUntil,
                        routes.stream().map(route -> new RouteDecision(route.routeId(), "ALLOWED",
                                List.of(), "LOCAL_ENFORCEMENT_DISABLED", List.of(), true, validUntil)).toList());
            }
        };
    }

    record RouteCandidate(String routeId, List<GeoPoint> points) {
        public RouteCandidate {
            points = points == null ? null : List.copyOf(points);
        }
    }

    record RouteDecision(String routeId, String outcome, List<String> restrictionIds,
            String reasonCode, List<Integer> affectedSegmentIndices, boolean permitsOperation,
            Instant validUntil) {
        public RouteDecision {
            restrictionIds = restrictionIds == null ? List.of() : List.copyOf(restrictionIds);
            affectedSegmentIndices = affectedSegmentIndices == null
                    ? List.of() : List.copyOf(affectedSegmentIndices);
        }
    }

    record RouteEvaluation(String policySnapshotId, Instant evaluatedAt, Instant validUntil,
            List<RouteDecision> results) {
        public RouteEvaluation {
            results = results == null ? List.of() : List.copyOf(results);
        }
    }
}
