package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;

record CameraSessionRecord(
        String sessionId,
        String viewerId,
        String status,
        String visibility,
        GeoPoint position,
        Double headingDegrees,
        Double compassDegrees,
        Double speedMetersPerSecond,
        double radiusMeters,
        double shareRadiusMeters,
        String statusMessage,
        Instant createdAt,
        Instant updatedAt,
        Instant expiresAt) {
    boolean activeAt(Instant now) {
        return "live".equals(status) && expiresAt.isAfter(now);
    }
}
