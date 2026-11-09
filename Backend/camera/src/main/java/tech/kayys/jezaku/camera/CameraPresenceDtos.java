package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;

import java.time.Instant;
import java.util.List;

final class CameraPresenceDtos {
    private CameraPresenceDtos() {
    }

    record CameraPresenceNearbyRequest(
            String viewerId,
            GeoPoint origin,
            Double headingDegrees,
            Double compassDegrees,
            double orientationDegrees,
            double radiusMeters,
            int limit,
            Instant now) {
    }

    record CameraPresenceNearbyResponse(
            int count,
            int totalAvailableCount,
            boolean truncated,
            CameraLayerSource source,
            CameraVisibilityReport visibility,
            List<CameraPresenceNearbyUser> users) {
        CameraPresenceNearbyResponse(
                int count,
                int totalAvailableCount,
                boolean truncated,
                CameraLayerSource source,
                List<CameraPresenceNearbyUser> users) {
            this(count, totalAvailableCount, truncated, source, null, users);
        }

        CameraPresenceNearbyResponse withSource(CameraLayerSource source) {
            return new CameraPresenceNearbyResponse(count, totalAvailableCount, truncated, source, visibility, users);
        }
    }

    record CameraPresenceNearbyUser(
            String userId,
            String displayName,
            String source,
            String avatarUrl,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            String visibility,
            String visibilityReason,
            double shareRadiusMeters,
            String statusMessage,
            Instant observedAt,
            Instant expiresAt,
            CameraPresenceProjection projection) {
    }

    record CameraPresenceProjection(
            Double distanceMeters,
            Double distanceRatio,
            String distanceBucket,
            Double bearingDegrees,
            Double relativeBearingDegrees,
            Double relativeX,
            Double relativeY,
            Double altitudeDeltaMeters,
            Long ageSeconds,
            Long expiresInSeconds,
            String freshnessState) {
    }
}
