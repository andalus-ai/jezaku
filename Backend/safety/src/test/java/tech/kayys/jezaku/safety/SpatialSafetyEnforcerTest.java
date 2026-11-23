package tech.kayys.jezaku.safety;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class SpatialSafetyEnforcerTest {
    private static final double LAT = -6.9;
    private static final double LON = 107.6;

    @Test
    void permitsOperationWhenNoRestrictionMatches() {
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = new FakeRepository(List.of(), false);

        var decision = enforcer.requirePermitted(LAT, LON, SpatialRestriction.Activity.PUBLISH);

        assertEquals(SpatialRestriction.Outcome.ALLOWED, decision.outcome());
        assertEquals("NO_MATCHING_RESTRICTION", decision.reasonCode());
    }

    @Test
    void blocksOperationInsideProhibitedArea() {
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = new FakeRepository(List.of(restriction(
                SpatialRestriction.Outcome.PROHIBITED, SpatialRestriction.Activity.PUBLISH)), false);

        WebApplicationException exception = assertThrows(WebApplicationException.class,
                () -> enforcer.requirePermitted(LAT, LON, SpatialRestriction.Activity.PUBLISH));

        assertEquals(403, exception.getResponse().getStatus());
    }

    @Test
    void failsClosedWhenPolicyStorageIsUnavailable() {
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = new FakeRepository(List.of(), true);

        WebApplicationException exception = assertThrows(WebApplicationException.class,
                () -> enforcer.requirePermitted(LAT, LON, SpatialRestriction.Activity.RENDER));

        assertEquals(503, exception.getResponse().getStatus());
    }

    @Test
    void doesNotBlockUnrelatedActivities() {
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = new FakeRepository(List.of(restriction(
                SpatialRestriction.Outcome.PROHIBITED, SpatialRestriction.Activity.PUBLISH)), false);

        var decision = enforcer.requirePermitted(LAT, LON, SpatialRestriction.Activity.RENDER);

        assertEquals(SpatialRestriction.Outcome.ALLOWED, decision.outcome());
    }

    private SpatialRestriction restriction(SpatialRestriction.Outcome outcome,
            SpatialRestriction.Activity activity) {
        Instant now = Instant.now();
        return new SpatialRestriction("restriction-test", 1, "GOVERNMENT", "authority-test",
                "ID.32", "test order", LAT, LON, 300, outcome, Set.of(activity),
                now.minusSeconds(30), now.plusSeconds(300), true);
    }

    private static final class FakeRepository implements SpatialPolicyRepository {
        private final List<SpatialRestriction> restrictions;
        private final boolean unavailable;

        private FakeRepository(List<SpatialRestriction> restrictions, boolean unavailable) {
            this.restrictions = restrictions;
            this.unavailable = unavailable;
        }

        @Override public void saveAuthority(AuthorityPrincipal principal, String actorId) { }
        @Override public Optional<AuthorityPrincipal> findAuthority(String principalId) { return Optional.empty(); }
        @Override public void saveRestriction(SpatialRestriction restriction, String actorId, String action, String reason) { }
        @Override public Optional<SpatialRestriction> findRestriction(String restrictionId) { return Optional.empty(); }
        @Override public List<SpatialRestriction> findActiveRestrictions(Instant at) {
            if (unavailable) throw new IllegalStateException("database unavailable");
            return restrictions;
        }
        @Override public SpatialRestriction revokeRestriction(String restrictionId, int expectedVersion,
                String actorId, String reason) { throw new UnsupportedOperationException(); }
        @Override public List<RestrictionAuditEvent> findAuditHistory(String restrictionId) { return List.of(); }
        @Override public List<AuthorityAuditEvent> findAuthorityAuditHistory(String principalId) { return List.of(); }
    }
}
