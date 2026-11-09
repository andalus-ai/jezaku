package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextRefresh;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionGuidance;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncPlansTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void followsContextRefreshWhenThereIsNoBacklog() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(false),
                delta(false),
                NOW);

        assertEquals(15, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(15), plan.nextSyncAt());
        assertEquals(15, plan.maxContextAgeSeconds());
        assertEquals(NOW.plusSeconds(15), plan.contextStaleAt());
        assertEquals(60, plan.heartbeatAfterSeconds());
        assertEquals(NOW.plusSeconds(60), plan.heartbeatDueAt());
        assertEquals(5, plan.positionUpdateAfterSeconds());
        assertEquals(NOW.plusSeconds(5), plan.positionUpdateDueAt());
        assertFalse(plan.eventBacklog());
        assertFalse(plan.deltaBacklog());
        assertEquals("ambient", plan.reason());
    }

    @Test
    void eventBacklogRequestsFastFollowUpSync() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(true),
                delta(false),
                NOW);

        assertEquals(1, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(1), plan.nextSyncAt());
        assertEquals(NOW.plusSeconds(15), plan.contextStaleAt());
        assertTrue(plan.eventBacklog());
        assertFalse(plan.deltaBacklog());
        assertEquals("event_backlog", plan.reason());
    }

    @Test
    void deltaBacklogTakesPriorityOverEventBacklog() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(true),
                delta(true),
                NOW);

        assertEquals(1, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(1), plan.nextSyncAt());
        assertTrue(plan.eventBacklog());
        assertTrue(plan.deltaBacklog());
        assertEquals("delta_backlog", plan.reason());
    }

    @Test
    void degradedOpsHealthRequestsSoonerFollowUpSync() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(false),
                delta(false),
                opsHealth("degraded"),
                NOW);

        assertEquals(5, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(5), plan.nextSyncAt());
        assertEquals(5, plan.maxContextAgeSeconds());
        assertEquals(NOW.plusSeconds(5), plan.contextStaleAt());
        assertFalse(plan.eventBacklog());
        assertFalse(plan.deltaBacklog());
        assertEquals("ops_health_degraded", plan.reason());
    }

    @Test
    void criticalOpsHealthRequestsFastFollowUpSync() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(false),
                delta(false),
                opsHealth("critical"),
                NOW);

        assertEquals(2, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(2), plan.nextSyncAt());
        assertEquals(2, plan.maxContextAgeSeconds());
        assertEquals(NOW.plusSeconds(2), plan.contextStaleAt());
        assertEquals("ops_health_critical", plan.reason());
    }

    @Test
    void backlogStillTakesPriorityOverOpsHealth() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(true),
                delta(false),
                opsHealth("critical"),
                NOW);

        assertEquals(1, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(1), plan.nextSyncAt());
        assertTrue(plan.eventBacklog());
        assertFalse(plan.deltaBacklog());
        assertEquals("event_backlog", plan.reason());
    }

    @Test
    void omitsDueTimesWhenSessionGuidanceHasNoActiveSchedule() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                inactiveSession(),
                context(new CameraContextRefresh(30, 30, null, "idle")),
                events(false),
                delta(false),
                NOW);

        assertEquals(30, plan.recommendedSyncAfterSeconds());
        assertEquals(NOW.plusSeconds(30), plan.nextSyncAt());
        assertNull(plan.heartbeatAfterSeconds());
        assertNull(plan.heartbeatDueAt());
        assertNull(plan.positionUpdateAfterSeconds());
        assertNull(plan.positionUpdateDueAt());
        assertEquals("idle", plan.reason());
    }

    @Test
    void toleratesSkippedContextDelta() {
        CameraSessionSyncPlan plan = CameraSessionSyncPlans.from(
                session(),
                context(new CameraContextRefresh(15, 15, null, "ambient")),
                events(false),
                null,
                opsHealth("healthy"),
                NOW);

        assertEquals(15, plan.recommendedSyncAfterSeconds());
        assertFalse(plan.eventBacklog());
        assertFalse(plan.deltaBacklog());
        assertEquals("ambient", plan.reason());
    }

    private CameraSessionResponse session() {
        return new CameraSessionResponse(
                "session",
                "viewer",
                "live",
                true,
                new CameraSessionGuidance(120, 0, 60, 5, true, true, false, true, "live_active"),
                "public",
                new CameraTelemetry("viewer", new GeoPoint(0, 0, null), null, null, 0, null, null, 100, NOW),
                100,
                "",
                NOW,
                NOW,
                NOW.plusSeconds(120));
    }

    private CameraSessionResponse inactiveSession() {
        return new CameraSessionResponse(
                "session",
                "viewer",
                "paused",
                false,
                new CameraSessionGuidance(120, 0, null, null, false, false, true, true, "paused"),
                "public",
                new CameraTelemetry("viewer", new GeoPoint(0, 0, null), null, null, 0, null, null, 100, NOW),
                100,
                "",
                NOW,
                NOW,
                NOW.plusSeconds(120));
    }

    private CameraContextResponse context(CameraContextRefresh refresh) {
        return new CameraContextResponse(
                "viewer",
                new CameraTelemetry("viewer", new GeoPoint(0, 0, null), null, null, 0, null, null, 100, NOW),
                0,
                0,
                null,
                null,
                refresh,
                null,
                List.of(),
                List.of(),
                NOW);
    }

    private CameraSessionEventListResponse events(boolean hasMore) {
        return new CameraSessionEventListResponse("session", 0, 0, hasMore, List.of(), NOW);
    }

    private CameraContextDeltaResponse delta(boolean truncated) {
        return new CameraContextDeltaResponse(
                "session",
                "radius=100.0|layers=people",
                false,
                "",
                0,
                truncated ? 2 : 0,
                truncated,
                0,
                0,
                0,
                0,
                0,
                List.of(),
                NOW);
    }

    private CameraOpsHealthResponse opsHealth(String status) {
        return new CameraOpsHealthResponse(
                status,
                "healthy".equals(status) ? 100 : 70,
                1,
                "healthy".equals(status) ? 1 : 0,
                "degraded".equals(status) ? 1 : 0,
                "critical".equals(status) ? 1 : 0,
                0,
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                NOW);
    }
}
