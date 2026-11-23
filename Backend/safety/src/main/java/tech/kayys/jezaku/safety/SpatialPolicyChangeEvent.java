package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.List;

/**
 * Minimal invalidation envelope. Consumers should re-evaluate affected
 * operations; this event is not an authorization decision or policy snapshot.
 */
public record SpatialPolicyChangeEvent(
        long policyRevision,
        String eventId,
        String restrictionId,
        int restrictionVersion,
        String action,
        String jurisdiction,
        String outcome,
        List<String> activities,
        Instant occurredAt) {
    public SpatialPolicyChangeEvent {
        if (policyRevision < 1) {
            throw new IllegalArgumentException("policyRevision must be positive");
        }
        if (eventId == null || eventId.isBlank()
                || restrictionId == null || restrictionId.isBlank()
                || restrictionVersion < 1
                || action == null || !List.of("CREATED", "UPDATED", "REVOKED").contains(action)
                || jurisdiction == null || jurisdiction.isBlank()
                || outcome == null || outcome.isBlank()
                || occurredAt == null) {
            throw new IllegalArgumentException("Policy change event fields are incomplete");
        }
        activities = List.copyOf(activities);
    }
}
