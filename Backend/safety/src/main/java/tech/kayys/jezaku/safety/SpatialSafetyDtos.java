package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.List;
import java.util.Set;

/** Public API contracts for authority-managed spatial safety policies. */
public final class SpatialSafetyDtos {
    private SpatialSafetyDtos() {
    }

    public record RestrictionCreateRequest(String jurisdiction, String legalBasis,
            double centerLatitude, double centerLongitude, double radiusMeters,
            SpatialRestriction.Outcome outcome, Set<SpatialRestriction.Activity> activities,
            Instant effectiveFrom, Instant expiresAt) {
    }

    public record RestrictionUpdateRequest(int expectedVersion, String jurisdiction, String legalBasis,
            double centerLatitude, double centerLongitude, double radiusMeters,
            SpatialRestriction.Outcome outcome, Set<SpatialRestriction.Activity> activities,
            Instant effectiveFrom, Instant expiresAt) {
    }

    public record RestrictionRevokeRequest(int expectedVersion, String reason) {
    }

    public record RestrictionResponse(SpatialRestriction restriction) {
    }

    public record RestrictionHistoryResponse(String restrictionId, int count,
            List<SpatialPolicyRepository.RestrictionAuditEvent> events) {
    }

    public record EvaluationRequest(double latitude, double longitude, SpatialRestriction.Activity activity) {
    }

    public record EvaluationResponse(SpatialSafetyPolicy.Decision decision, Instant evaluatedAt) {
    }

    /** One bounded request evaluated against a single immutable policy snapshot. */
    public record EvaluationBatchRequest(List<EvaluationRequest> requests) {
    }

    /** Results preserve request order and share the same evaluation timestamp. */
    public record EvaluationBatchResponse(List<EvaluationResponse> results, Instant evaluatedAt) {
    }
}
