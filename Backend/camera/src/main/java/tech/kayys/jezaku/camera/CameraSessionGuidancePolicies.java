package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraSessionGuidance;

import java.time.Duration;
import java.time.Instant;

final class CameraSessionGuidancePolicies {
    private static final int MAX_HEARTBEAT_AFTER_SECONDS = 60;
    private static final int FAST_POSITION_UPDATE_SECONDS = 3;
    private static final int ACTIVE_POSITION_UPDATE_SECONDS = 5;
    private static final int IDLE_POSITION_UPDATE_SECONDS = 10;

    private CameraSessionGuidancePolicies() {
    }

    static CameraSessionGuidance from(CameraSessionRecord record, Instant now) {
        boolean active = record.activeAt(now);
        long expiresInSeconds = nonNegativeSeconds(now, record.expiresAt());
        long telemetryAgeSeconds = nonNegativeSeconds(record.updatedAt(), now);
        return new CameraSessionGuidance(
                expiresInSeconds,
                telemetryAgeSeconds,
                active ? heartbeatAfterSeconds(expiresInSeconds) : null,
                active ? positionUpdateAfterSeconds(record.speedMetersPerSecond()) : null,
                active,
                active,
                "paused".equals(record.status()),
                !"ended".equals(record.status()),
                reason(record, active));
    }

    private static int heartbeatAfterSeconds(long expiresInSeconds) {
        long halfWindow = Math.max(1, expiresInSeconds / 2);
        return (int) Math.min(MAX_HEARTBEAT_AFTER_SECONDS, halfWindow);
    }

    private static int positionUpdateAfterSeconds(Double speedMetersPerSecond) {
        if (speedMetersPerSecond == null || speedMetersPerSecond < 0.2) {
            return IDLE_POSITION_UPDATE_SECONDS;
        }
        if (speedMetersPerSecond < 1.5) {
            return ACTIVE_POSITION_UPDATE_SECONDS;
        }
        return FAST_POSITION_UPDATE_SECONDS;
    }

    private static String reason(CameraSessionRecord record, boolean active) {
        if ("ended".equals(record.status())) {
            return CameraSyncContract.SESSION_GUIDANCE_REASON_ENDED;
        }
        if ("paused".equals(record.status())) {
            return CameraSyncContract.SESSION_GUIDANCE_REASON_PAUSED;
        }
        return active
                ? CameraSyncContract.SESSION_GUIDANCE_REASON_LIVE_ACTIVE
                : CameraSyncContract.SESSION_GUIDANCE_REASON_EXPIRED;
    }

    private static long nonNegativeSeconds(Instant start, Instant end) {
        return Math.max(0, Duration.between(start, end).toSeconds());
    }
}
