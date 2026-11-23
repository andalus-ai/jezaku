package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/** Durable storage contract for authority grants and spatial policy records. */
public interface SpatialPolicyRepository {
    void saveAuthority(AuthorityPrincipal principal);

    Optional<AuthorityPrincipal> findAuthority(String principalId);

    void saveRestriction(SpatialRestriction restriction, String actorId, String action, String reason);

    Optional<SpatialRestriction> findRestriction(String restrictionId);

    List<SpatialRestriction> findActiveRestrictions(Instant at);

    SpatialRestriction revokeRestriction(String restrictionId, int expectedVersion,
            String actorId, String reason, Instant revokedAt);

    List<RestrictionAuditEvent> findAuditHistory(String restrictionId);

    record RestrictionAuditEvent(
            String eventId,
            String restrictionId,
            int restrictionVersion,
            String action,
            String actorId,
            String reason,
            String snapshotJson,
            Instant occurredAt) {
    }
}
