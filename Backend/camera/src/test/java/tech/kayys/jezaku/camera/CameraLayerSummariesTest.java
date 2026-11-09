package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchorConfidence;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class CameraLayerSummariesTest {
    @Test
    void summarizesEmptyLayer() {
        CameraLayerSummary summary = CameraLayerSummaries.from(List.of());

        assertNull(summary.nearestDistanceMeters());
        assertNull(summary.farthestDistanceMeters());
        assertEquals(0, summary.perimeterCount());
        assertEquals(0, summary.liveCount());
        assertEquals(0, summary.freshCount());
        assertEquals(0, summary.staticCount());
        assertEquals(0, summary.arReadyMemoryCount());
        assertEquals(0, summary.lowConfidenceMemoryCount());
        assertEquals(0, summary.needsRefinementMemoryCount());
    }

    @Test
    void summarizesReturnedDots() {
        CameraDot live = dot("live", "live_session", "near", "fresh", 12.4);
        CameraDot staticPerimeter = dot("memory", "seed", "perimeter", "static", 92.6);

        CameraLayerSummary summary = CameraLayerSummaries.from(List.of(live, staticPerimeter));

        assertEquals(12.4, summary.nearestDistanceMeters());
        assertEquals(92.6, summary.farthestDistanceMeters());
        assertEquals(1, summary.perimeterCount());
        assertEquals(1, summary.liveCount());
        assertEquals(1, summary.freshCount());
        assertEquals(1, summary.staticCount());
        assertEquals(0, summary.arReadyMemoryCount());
        assertEquals(0, summary.lowConfidenceMemoryCount());
        assertEquals(0, summary.needsRefinementMemoryCount());
    }

    @Test
    void summarizesMemoryAnchorConfidence() {
        CameraDot arReady = memoryDot("ar_ready", "high", true, 96, List.of());
        CameraDot needsRefinement = memoryDot(
                "needs_refinement",
                "low",
                false,
                42,
                List.of("recapture_with_better_gps", "calibrate_compass"));

        CameraLayerSummary summary = CameraLayerSummaries.from(List.of(arReady, needsRefinement));

        assertEquals(1, summary.arReadyMemoryCount());
        assertEquals(1, summary.lowConfidenceMemoryCount());
        assertEquals(1, summary.needsRefinementMemoryCount());
    }

    private CameraDot dot(
            String targetId,
            String source,
            String distanceBucket,
            String freshnessState,
            double distanceMeters) {
        return new CameraDot(
                "people",
                "presence",
                targetId,
                "owner",
                null,
                source,
                "public",
                Instant.EPOCH.plusSeconds(120),
                4,
                116L,
                distanceBucket,
                freshnessState,
                "Title",
                "",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                new GeoPoint(0, 0, null),
                null,
                null,
                distanceMeters,
                0.5,
                0,
                0,
                0,
                0,
                null,
                Instant.EPOCH,
                List.of());
    }

    private CameraDot memoryDot(
            String targetId,
            String confidenceLevel,
            boolean arReady,
            int score,
            List<String> recommendedActions) {
        return new CameraDot(
                "memories",
                "memory",
                targetId,
                "owner",
                "media_" + targetId,
                "seed",
                "public",
                null,
                10,
                null,
                "near",
                "static",
                "Title",
                "",
                "https://cdn.jezaku.local/" + targetId + ".jpg",
                "https://cdn.jezaku.local/" + targetId + "-thumb.jpg",
                "active",
                "approved",
                true,
                true,
                new CameraAnchor(
                        "geo",
                        confidenceLevel,
                        arReady,
                        new GeoPoint(0, 0, 10.0),
                        90.0,
                        90.0,
                        -5.0,
                        0.5,
                        4.0,
                        new CameraAnchorConfidence(
                                score,
                                confidenceLevel,
                                List.of("gps_accuracy_high"),
                                recommendedActions)),
                new GeoPoint(0, 0, 10.0),
                90.0,
                90.0,
                16.0,
                0.16,
                0,
                0,
                0,
                0,
                null,
                Instant.EPOCH,
                List.of());
    }
}
