package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraDotProjection.Projection;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchorConfidence;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.spatial.AnchorConfidencePolicy;
import tech.kayys.jezaku.spatial.AnchorConfidencePolicy.AnchorConfidence;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;

class SeedCameraMemoryOverlayClient {
    public Uni<CameraMemoryOverlayResponse> minimap(CameraMemoryOverlayRequest request) {
        return Uni.createFrom().item(() -> {
            List<CameraMemoryOverlayDot> available = seeds(request.now()).stream()
                    .filter(seed -> "public".equals(seed.visibility()))
                    .filter(seed -> request.viewerId().isEmpty() || !seed.ownerId().equals(request.viewerId()))
                    .map(seed -> toDot(seed, request))
                    .filter(dot -> dot.distanceMeters() <= request.radiusMeters())
                    .sorted(Comparator.comparingDouble(CameraMemoryOverlayDot::distanceMeters)
                            .thenComparing(CameraMemoryOverlayDot::id))
                    .toList();
            List<CameraMemoryOverlayDot> dots = available.stream()
                    .limit(request.limit())
                    .toList();
            return new CameraMemoryOverlayResponse(
                    dots.size(),
                    available.size(),
                    available.size() > dots.size(),
                    CameraLayerSources.seed(request.now()),
                    dots);
        });
    }

    private CameraMemoryOverlayDot toDot(MemorySeed seed, CameraMemoryOverlayRequest request) {
        Projection projection = CameraDotProjection.from(
                request.origin(),
                seed.position(),
                request.orientationDegrees(),
                request.radiusMeters());
        return new CameraMemoryOverlayDot(
                seed.memoryId(),
                seed.ownerId(),
                seed.mediaId(),
                "seed",
                seed.visibility(),
                seed.mediaStatus(),
                seed.moderationStatus(),
                seed.memoryAttachable(),
                seed.publicMemoryEligible(),
                seed.caption(),
                seed.placeId(),
                seed.mediaUrl(),
                seed.thumbnailUrl(),
                anchor(seed),
                seed.position(),
                seed.headingDegrees(),
                seed.compassDegrees(),
                projection.distanceMeters(),
                projection.distanceRatio(),
                projection.bearingDegrees(),
                projection.relativeBearingDegrees(),
                projection.relativeX(),
                projection.relativeY(),
                projection.altitudeDeltaMeters(),
                seed.capturedAt());
    }

    private List<MemorySeed> seeds(Instant now) {
        return List.of(
                new MemorySeed(
                        "memory_seed_courtyard",
                        "user_current",
                        "media_seed_courtyard",
                        "https://cdn.jezaku.local/media/seed/courtyard.jpg",
                        "https://cdn.jezaku.local/memories/courtyard-thumb.jpg",
                        "active",
                        "approved",
                        true,
                        true,
                        "Morning light near the campus path",
                        new GeoPoint(-6.890620, 107.610790, 742.0),
                        42.0,
                        42.0,
                        -4.0,
                        1.0,
                        3.8,
                        "geo",
                        "public",
                        "place_bandung_campus",
                        now.minusSeconds(480)),
                new MemorySeed(
                        "memory_seed_rooftop",
                        "user_rooftop",
                        "media_seed_rooftop",
                        "https://cdn.jezaku.local/media/seed/rooftop.webp",
                        "https://cdn.jezaku.local/memories/rooftop-thumb.jpg",
                        "active",
                        "approved",
                        true,
                        true,
                        "Skyline marker beside the wall",
                        new GeoPoint(-6.890580, 107.610970, 746.4),
                        87.0,
                        87.0,
                        -8.5,
                        0.5,
                        4.2,
                        "geo",
                        "public",
                        "place_rooftop_lane",
                        now.minusSeconds(360)),
                new MemorySeed(
                        "memory_seed_private",
                        "user_private",
                        null,
                        "https://cdn.jezaku.local/memories/private.jpg",
                        "https://cdn.jezaku.local/memories/private-thumb.jpg",
                        "external",
                        "unverified",
                        false,
                        false,
                        "Only visible to owner",
                        new GeoPoint(-6.890700, 107.610860, 741.8),
                        180.0,
                        181.0,
                        null,
                        null,
                        18.0,
                        "geo",
                        "private",
                        "place_bandung_campus",
                        now.minusSeconds(300)),
                new MemorySeed(
                        "memory_seed_far",
                        "user_far",
                        null,
                        "https://cdn.jezaku.local/memories/far.jpg",
                        "https://cdn.jezaku.local/memories/far-thumb.jpg",
                        "external",
                        "unverified",
                        false,
                        false,
                        "Outside the minimap radius",
                        new GeoPoint(-6.893100, 107.613300, 739.2),
                        12.0,
                        12.0,
                        null,
                        null,
                        25.0,
                        "geo",
                        "public",
                        null,
                        now.minusSeconds(240)),
                new MemorySeed(
                        "camera_test_north_memory",
                        "camera_owner",
                        null,
                        "https://cdn.jezaku.local/memories/north.jpg",
                        "https://cdn.jezaku.local/memories/north-thumb.jpg",
                        "external",
                        "unverified",
                        false,
                        false,
                        "North camera memory",
                        new GeoPoint(10.00045, 20.0, 94.0),
                        0.0,
                        0.0,
                        -6.0,
                        0.0,
                        4.5,
                        "geo",
                        "public",
                        "place_camera_test",
                        now.minusSeconds(60)));
    }

    private CameraAnchor anchor(MemorySeed seed) {
        CameraAnchorConfidence confidence = anchorConfidence(seed);
        return new CameraAnchor(
                seed.anchorType(),
                confidence.level(),
                !"low".equals(confidence.level()),
                seed.position(),
                seed.headingDegrees(),
                seed.compassDegrees(),
                seed.pitchDegrees(),
                seed.rollDegrees(),
                seed.gpsAccuracyMeters(),
                confidence);
    }

    private CameraAnchorConfidence anchorConfidence(MemorySeed seed) {
        AnchorConfidence confidence = AnchorConfidencePolicy.evaluate(
                seed.anchorType(),
                seed.position().altitudeMeters() != null,
                seed.headingDegrees(),
                seed.compassDegrees(),
                seed.pitchDegrees(),
                seed.rollDegrees(),
                seed.gpsAccuracyMeters());
        return new CameraAnchorConfidence(
                confidence.score(),
                confidence.level(),
                confidence.reasons(),
                confidence.recommendedActions());
    }

    private record MemorySeed(
            String memoryId,
            String ownerId,
            String mediaId,
            String mediaUrl,
            String thumbnailUrl,
            String mediaStatus,
            String moderationStatus,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            String caption,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters,
            String anchorType,
            String visibility,
            String placeId,
            Instant capturedAt) {
    }
}
