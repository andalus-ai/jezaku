package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

/**
 * Defines the memory overlay transfer objects used between the camera layer and memory providers.
 */
final class CameraMemoryOverlayDtos {
    private CameraMemoryOverlayDtos() {
    }

    record CameraMemoryOverlayRequest(
            String viewerId,
            GeoPoint origin,
            Double headingDegrees,
            Double compassDegrees,
            double orientationDegrees,
            double radiusMeters,
            int limit,
            Instant now) {
    }

    record CameraMemoryOverlayResponse(
            int count,
            int totalAvailableCount,
            boolean truncated,
            CameraLayerSource source,
            List<CameraMemoryOverlayDot> dots) {
        CameraMemoryOverlayResponse withSource(CameraLayerSource source) {
            return new CameraMemoryOverlayResponse(count, totalAvailableCount, truncated, source, dots);
        }
    }

    /**
     * Carries a filtered memory overlay response together with the audience visibility report that produced it.
     */
    record CameraMemoryVisibilityResult(
            CameraMemoryOverlayResponse response,
            CameraVisibilityReport visibility) {
    }

    record CameraMemoryOverlayDot(
            String id,
            String ownerId,
            String mediaId,
            String source,
            String visibility,
            String mediaStatus,
            String moderationStatus,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            String title,
            String subtitle,
            String mediaUrl,
            String thumbnailUrl,
            CameraAnchor anchor,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            double distanceMeters,
            double distanceRatio,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            Instant capturedAt) {
    }
}
