package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/** Durable storage contract for authority grants and spatial policy records. */
public interface SpatialPolicyRepository {
    void saveAuthority(AuthorityPrincipal principal, String actorId);
    Optional<AuthorityPrincipal> findAuthority(String principalId);
    void saveRestriction(SpatialRestriction restriction, String actorId, String action, String reason);
    Optional<SpatialRestriction> findRestriction(String restrictionId);
    List<SpatialRestriction> findActiveRestrictions(Instant at);
    List<SpatialPolicyChangeEvent> findPolicyChangesAfter(long revision, int limit);
    long currentPolicyRevision();

    /**
     * Returns active policy and its monotonic revision from one consistent
     * storage snapshot. Durable implementations must override atomically.
     */
    default PolicySnapshot findPolicySnapshot(Instant at) {
        return new PolicySnapshot(0L, findActiveRestrictions(at));
    }

    SpatialRestriction revokeRestriction(String restrictionId, int expectedVersion, String actorId, String reason);
    List<RestrictionAuditEvent> findAuditHistory(String restrictionId);
    List<AuthorityAuditEvent> findAuthorityAuditHistory(String principalId);

    record PolicySnapshot(long revision, List<SpatialRestriction> restrictions) {
        public PolicySnapshot {
            if (revision < 0) throw new IllegalArgumentException("revision cannot be negative");
            restrictions = List.copyOf(restrictions);
        }
    }

    record AuthorityAuditEvent(String eventId, String principalId, String action,
            String actorId, String snapshotJson, Instant occurredAt) { }

    record RestrictionAuditEvent(String eventId, String restrictionId, int restrictionVersion,
            String action, String actorId, String reason, String snapshotJson, Instant occurredAt) { }
}
