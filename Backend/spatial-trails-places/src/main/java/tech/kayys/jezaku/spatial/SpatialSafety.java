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

    /** Read ordered policy invalidation events after the last successfully processed revision. */
    default PolicyChangePage readPolicyChanges(long afterRevision, int limit) {
        throw new WebApplicationException("Spatial policy change feed is unavailable", 503);
    }

    record PolicyChangeEvent(long policyRevision, String eventId, String eventType, int eventVersion,
            String restrictionId, int restrictionVersion, String action, String jurisdiction, String outcome,
            List<String> activities, Instant occurredAt) {
        public PolicyChangeEvent {
            activities = activities == null ? List.of() : List.copyOf(activities);
        }
    }

    record PolicyChangePage(long currentRevision, long afterRevision, List<PolicyChangeEvent> events) {
        public PolicyChangePage {
            events = events == null ? List.of() : List.copyOf(events);
        }
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
            List<RouteDecision> results, long policyRevision) {
        public RouteEvaluation {
            results = results == null ? List.of() : List.copyOf(results);
            if (policyRevision < 0) {
                throw new IllegalArgumentException("policyRevision cannot be negative");
            }
        }

        public RouteEvaluation(String policySnapshotId, Instant evaluatedAt, Instant validUntil,
                List<RouteDecision> results) {
            this(policySnapshotId, evaluatedAt, validUntil, results, 0L);
        }
    }
}
