package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionGuidance;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionGuidancePoliciesTest {
    private static final Instant NOW = Instant.parse("2026-05-31T00:00:00Z");

    @Test
    void liveActiveSessionProvidesHeartbeatAndSensorCadence() {
        CameraSessionGuidance guidance = CameraSessionGuidancePolicies.from(
                session("live", 0.8, NOW, NOW.plusSeconds(180)),
                NOW.plusSeconds(30));

        assertEquals(150, guidance.expiresInSeconds());
        assertEquals(30, guidance.telemetryAgeSeconds());
        assertEquals(60, guidance.heartbeatAfterSeconds());
        assertEquals(5, guidance.positionUpdateAfterSeconds());
        assertTrue(guidance.canHeartbeat());
        assertTrue(guidance.canPause());
        assertFalse(guidance.canResume());
        assertTrue(guidance.canEnd());
        assertEquals("live_active", guidance.reason());
    }

    @Test
    void movingLiveSessionUsesFastPositionCadence() {
        CameraSessionGuidance guidance = CameraSessionGuidancePolicies.from(
                session("live", 2.0, NOW, NOW.plusSeconds(40)),
                NOW);

        assertEquals(20, guidance.heartbeatAfterSeconds());
        assertEquals(3, guidance.positionUpdateAfterSeconds());
    }

    @Test
    void pausedSessionCanResumeButDoesNotHeartbeat() {
        CameraSessionGuidance guidance = CameraSessionGuidancePolicies.from(
                session("paused", 0.8, NOW, NOW.plusSeconds(180)),
                NOW.plusSeconds(30));

        assertEquals(150, guidance.expiresInSeconds());
        assertNull(guidance.heartbeatAfterSeconds());
        assertNull(guidance.positionUpdateAfterSeconds());
        assertFalse(guidance.canHeartbeat());
        assertFalse(guidance.canPause());
        assertTrue(guidance.canResume());
        assertTrue(guidance.canEnd());
        assertEquals("paused", guidance.reason());
    }

    @Test
    void endedSessionHasNoControls() {
        CameraSessionGuidance guidance = CameraSessionGuidancePolicies.from(
                session("ended", 0.8, NOW.minusSeconds(30), NOW.minusSeconds(30)),
                NOW);

        assertEquals(0, guidance.expiresInSeconds());
        assertFalse(guidance.canHeartbeat());
        assertFalse(guidance.canPause());
        assertFalse(guidance.canResume());
        assertFalse(guidance.canEnd());
        assertEquals("ended", guidance.reason());
    }

    @Test
    void expiredLiveSessionCanOnlyBeClosed() {
        CameraSessionGuidance guidance = CameraSessionGuidancePolicies.from(
                session("live", 0.8, NOW.minusSeconds(120), NOW.minusSeconds(1)),
                NOW);

        assertEquals(0, guidance.expiresInSeconds());
        assertNull(guidance.heartbeatAfterSeconds());
        assertFalse(guidance.canHeartbeat());
        assertFalse(guidance.canPause());
        assertFalse(guidance.canResume());
        assertTrue(guidance.canEnd());
        assertEquals("expired", guidance.reason());
    }

    private CameraSessionRecord session(
            String status,
            Double speedMetersPerSecond,
            Instant updatedAt,
            Instant expiresAt) {
        return new CameraSessionRecord(
                "session-id",
                "viewer-id",
                status,
                "public",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                42.0,
                42.0,
                speedMetersPerSecond,
                100.0,
                100.0,
                "Live",
                NOW.minusSeconds(60),
                updatedAt,
                expiresAt);
    }
}
