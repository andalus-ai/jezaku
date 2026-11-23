package tech.kayys.jezaku.safety;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
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

    @Test
    void capturesOneSnapshotAndReusesItAcrossBatch() {
        FakeRepository repository = new FakeRepository(List.of(restriction(
                SpatialRestriction.Outcome.PROHIBITED, SpatialRestriction.Activity.DISCOVER)), false);
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = repository;

        var snapshot = enforcer.captureSnapshot();
        var decisions = enforcer.evaluateBatch(snapshot, List.of(
                new SpatialSafetyEnforcer.EvaluationTarget(LAT, LON, SpatialRestriction.Activity.DISCOVER),
                new SpatialSafetyEnforcer.EvaluationTarget(-6.9005, 107.6005, SpatialRestriction.Activity.DISCOVER),
                new SpatialSafetyEnforcer.EvaluationTarget(LAT, LON, SpatialRestriction.Activity.RENDER)));

        assertEquals(1, repository.readCount);
        assertEquals(SpatialRestriction.Outcome.PROHIBITED, decisions.get(0).outcome());
        assertEquals(SpatialRestriction.Outcome.PROHIBITED, decisions.get(1).outcome());
        assertEquals(SpatialRestriction.Outcome.ALLOWED, decisions.get(2).outcome());
        assertEquals(3, decisions.size());
    }

    @Test
    void routeEvaluationUsesOneSnapshotAndBlocksAnIntersectingSegment() {
        FakeRepository repository = new FakeRepository(List.of(restriction(
                SpatialRestriction.Outcome.PROHIBITED, SpatialRestriction.Activity.NAVIGATE)), false);
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = repository;
        var snapshot = enforcer.captureSnapshot();
        var route = List.of(
                new SpatialRouteGeometry.Point(-6.9, 107.59),
                new SpatialRouteGeometry.Point(-6.9, 107.61));

        var decision = enforcer.evaluateRoute(snapshot, route, 0,
                SpatialRestriction.Activity.NAVIGATE);

        assertEquals(1, repository.readCount);
        assertEquals(SpatialRestriction.Outcome.PROHIBITED, decision.outcome());
        assertEquals(List.of(0), decision.affectedSegmentIndices());
        WebApplicationException denied = assertThrows(WebApplicationException.class,
                () -> enforcer.requireRoutePermitted(snapshot, route, 0,
                        SpatialRestriction.Activity.NAVIGATE));
        assertEquals(403, denied.getResponse().getStatus());
        assertEquals(1, repository.readCount, "route evaluation must not reload policy");
    }

    @Test
    void snapshotCopiesRestrictionsAndUsesOneEvaluationInstant() {
        List<SpatialRestriction> mutable = new ArrayList<>();
        mutable.add(restriction(SpatialRestriction.Outcome.CAUTION, SpatialRestriction.Activity.RENDER));
        Instant evaluatedAt = Instant.now();
        var snapshot = new SpatialSafetyEnforcer.PolicySnapshot(evaluatedAt, mutable);
        mutable.clear();

        assertEquals(1, snapshot.restrictions().size());
        assertEquals(evaluatedAt, snapshot.evaluatedAt());
        assertThrows(UnsupportedOperationException.class, () -> snapshot.restrictions().clear());
    }

    @Test
    void rejectsOversizedBatchBeforeEvaluating() {
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        FakeRepository repository = new FakeRepository(List.of(), false);
        enforcer.repository = repository;
        var snapshot = enforcer.captureSnapshot();
        List<SpatialSafetyEnforcer.EvaluationTarget> targets = java.util.stream.IntStream
                .range(0, SpatialSafetyEnforcer.MAX_BATCH_SIZE + 1)
                .mapToObj(index -> new SpatialSafetyEnforcer.EvaluationTarget(
                        LAT, LON, SpatialRestriction.Activity.DISCOVER))
                .toList();

        assertThrows(IllegalArgumentException.class, () -> enforcer.evaluateBatch(snapshot, targets));
        assertEquals(1, repository.readCount, "only snapshot capture may read policy storage");
    }

    @Test
    void failsClosedWhenRepositoryReturnsNullSnapshot() {
        SpatialSafetyEnforcer enforcer = new SpatialSafetyEnforcer();
        enforcer.repository = new FakeRepository(null, false);

        WebApplicationException exception = assertThrows(WebApplicationException.class,
                enforcer::captureSnapshot);

        assertEquals(503, exception.getResponse().getStatus());
    }

    private static SpatialRestriction restriction(SpatialRestriction.Outcome outcome,
            SpatialRestriction.Activity activity) {
        Instant now = Instant.now();
        return new SpatialRestriction("restriction-test", 1, "GOVERNMENT", "authority-test",
                "ID.32", "test order", LAT, LON, 300, outcome, Set.of(activity),
                now.minusSeconds(30), now.plusSeconds(300), true);
    }

    private static final class FakeRepository implements SpatialPolicyRepository {
        private final List<SpatialRestriction> restrictions;
        private final boolean unavailable;
        private int readCount;

        private FakeRepository(List<SpatialRestriction> restrictions, boolean unavailable) {
            this.restrictions = restrictions;
            this.unavailable = unavailable;
        }

        @Override public void saveAuthority(AuthorityPrincipal principal, String actorId) { }
        @Override public Optional<AuthorityPrincipal> findAuthority(String principalId) { return Optional.empty(); }
        @Override public void saveRestriction(SpatialRestriction restriction, String actorId, String action, String reason) { }
        @Override public Optional<SpatialRestriction> findRestriction(String restrictionId) { return Optional.empty(); }
        @Override public List<SpatialRestriction> findActiveRestrictions(Instant at) {
            readCount++;
            if (unavailable) throw new IllegalStateException("database unavailable");
            return restrictions;
        }
        @Override public SpatialRestriction revokeRestriction(String restrictionId, int expectedVersion,
                String actorId, String reason) { throw new UnsupportedOperationException(); }
        @Override public List<RestrictionAuditEvent> findAuditHistory(String restrictionId) { return List.of(); }
        @Override public List<AuthorityAuditEvent> findAuthorityAuditHistory(String principalId) { return List.of(); }
    }
}
