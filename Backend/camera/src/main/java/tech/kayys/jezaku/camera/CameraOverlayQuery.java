package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;

public record CameraOverlayQuery(
        String viewerId,
        GeoPoint origin,
        Double headingDegrees,
        Double compassDegrees,
        double orientationDegrees,
        double radiusMeters,
        int limitPerLayer,
        Instant now) {
}
