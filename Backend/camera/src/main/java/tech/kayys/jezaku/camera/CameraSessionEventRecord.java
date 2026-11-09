package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;

record CameraSessionEventRecord(
        String eventId,
        long sequence,
        String sessionId,
        String viewerId,
        String type,
        String status,
        String visibility,
        GeoPoint position,
        Double headingDegrees,
        Double compassDegrees,
        Double speedMetersPerSecond,
        double radiusMeters,
        double shareRadiusMeters,
        String statusMessage,
        Instant eventAt) {
}
