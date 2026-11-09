package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncFreshness;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncFreshnessPoliciesTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void mirrorsNormalSyncPlanSchedule() {
        CameraSessionSyncFreshness freshness = CameraSessionSyncFreshnessPolicies.from(
                plan(15, 30, false, false, "ambient"),
                NOW);

        assertEquals(NOW, freshness.generatedAt());
        assertEquals(15, freshness.refreshAfterSeconds());
        assertEquals(NOW.plusSeconds(15), freshness.refreshRecommendedAt());
        assertEquals(30, freshness.maxAgeSeconds());
        assertEquals(NOW.plusSeconds(30), freshness.staleAt());
        assertFalse(freshness.refreshImmediately());
        assertFalse(freshness.stale());
        assertEquals("ambient", freshness.reason());
    }

    @Test
    void marksBacklogPlansAsImmediateRefresh() {
        CameraSessionSyncFreshness freshness = CameraSessionSyncFreshnessPolicies.from(
                plan(1, 15, true, false, CameraSyncContract.SYNC_REASON_EVENT_BACKLOG),
                NOW);

        assertEquals(1, freshness.refreshAfterSeconds());
        assertEquals(NOW.plusSeconds(1), freshness.refreshRecommendedAt());
        assertTrue(freshness.refreshImmediately());
        assertFalse(freshness.stale());
        assertEquals(CameraSyncContract.SYNC_REASON_EVENT_BACKLOG, freshness.reason());
    }

    @Test
    void treatsMissingSyncPlanAsImmediatelyStale() {
        CameraSessionSyncFreshness freshness = CameraSessionSyncFreshnessPolicies.from(null, NOW);

        assertEquals(NOW, freshness.generatedAt());
        assertEquals(0, freshness.refreshAfterSeconds());
        assertEquals(NOW, freshness.refreshRecommendedAt());
        assertEquals(0, freshness.maxAgeSeconds());
        assertEquals(NOW, freshness.staleAt());
        assertTrue(freshness.refreshImmediately());
        assertTrue(freshness.stale());
        assertEquals("sync_plan_unavailable", freshness.reason());
    }

    private CameraSessionSyncPlan plan(
            int recommendedSyncAfterSeconds,
            int maxContextAgeSeconds,
            boolean eventBacklog,
            boolean deltaBacklog,
            String reason) {
        return new CameraSessionSyncPlan(
                recommendedSyncAfterSeconds,
                NOW.plusSeconds(recommendedSyncAfterSeconds),
                maxContextAgeSeconds,
                NOW.plusSeconds(maxContextAgeSeconds),
                60,
                NOW.plusSeconds(60),
                5,
                NOW.plusSeconds(5),
                eventBacklog,
                deltaBacklog,
                reason);
    }
}
