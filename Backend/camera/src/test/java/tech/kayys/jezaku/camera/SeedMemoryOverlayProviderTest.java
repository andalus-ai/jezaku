package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchorConfidence;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SeedMemoryOverlayProviderTest {
    @Test
    void mapsMemoryOverlayClientResponseIntoCameraLayer() {
        SeedMemoryOverlayProvider provider = new SeedMemoryOverlayProvider();
        Instant now = Instant.parse("2026-06-03T00:00:00Z");
        GeoPoint origin = new GeoPoint(-6.890620, 107.610790, 742.0);
        CameraVisibilityReport visibility = new CameraVisibilityReport(
                "social_audience",
                "social",
                "healthy",
                false,
                2,
                2,
                0,
                List.of());
        provider.memoryVisibilityClient = (request, response) ->
                Uni.createFrom().item(new CameraMemoryVisibilityResult(response, visibility));
        provider.memoryOverlayClient = request -> {
            assertEquals("viewer", request.viewerId());
            assertEquals(origin, request.origin());
            assertEquals(88.0, request.headingDegrees());
            assertEquals(90.0, request.compassDegrees());
            assertEquals(90.0, request.orientationDegrees());
            assertEquals(100.0, request.radiusMeters());
            assertEquals(1, request.limit());
            assertEquals(now, request.now());
            return Uni.createFrom().item(new CameraMemoryOverlayResponse(
                    2,
                    2,
                    false,
                    CameraLayerSources.http("memory_service", now),
                    List.of(lowConfidenceMemory(now), arReadyMemory(now))));
        };

        CameraLayer layer = provider.layer(new CameraOverlayQuery("viewer", origin, 88.0, 90.0, 90.0, 100.0, 1, now))
                .await().indefinitely();

        assertEquals("memories", layer.layer());
        assertEquals("ready", layer.status());
        assertEquals("memory_service", layer.source().effectiveSource());
        assertEquals(true, layer.source().healthy());
        assertEquals(1, layer.count());
        assertEquals(2, layer.totalAvailable());
        assertTrue(layer.truncated());
        assertEquals(1, layer.summary().lowConfidenceMemoryCount());
        assertEquals(1, layer.summary().needsRefinementMemoryCount());
        assertEquals("memories", layer.visibility().layer());
        assertEquals("social_audience", layer.visibility().mode());
        assertEquals(2, layer.visibility().candidateCount());
        assertEquals("memory_low", layer.dots().getFirst().targetId());
        assertEquals("memory_service", layer.dots().getFirst().source());
        assertEquals("visible", layer.dots().getFirst().visibilityReason());
        assertEquals("low", layer.dots().getFirst().anchor().confidence().level());
        assertEquals("review_anchor", layer.dots().getFirst().actions().get(2).type());
        assertEquals("/memories/memory_low/anchor", layer.dots().getFirst().actions().get(2).href());
    }

    private CameraMemoryOverlayDot lowConfidenceMemory(Instant now) {
        return memory(
                "memory_low",
                12.0,
                0.12,
                lowConfidenceAnchor(),
                now.minusSeconds(90));
    }

    private CameraMemoryOverlayDot arReadyMemory(Instant now) {
        return memory(
                "memory_ready",
                24.0,
                0.24,
                arReadyAnchor(),
                now.minusSeconds(120));
    }

    private CameraMemoryOverlayDot memory(
            String id,
            double distanceMeters,
            double distanceRatio,
            CameraAnchor anchor,
            Instant capturedAt) {
        return new CameraMemoryOverlayDot(
                id,
                "owner_" + id,
                "media_" + id,
                "memory_service",
                "public",
                "active",
                "approved",
                true,
                true,
                "Memory " + id,
                "place_test",
                "https://cdn.jezaku.local/" + id + ".jpg",
                "https://cdn.jezaku.local/" + id + "-thumb.jpg",
                anchor,
                anchor.position(),
                anchor.headingDegrees(),
                anchor.compassDegrees(),
                distanceMeters,
                distanceRatio,
                45.0,
                3.0,
                0.05,
                -0.11,
                1.5,
                capturedAt);
    }

    private CameraAnchor lowConfidenceAnchor() {
        return new CameraAnchor(
                "geo",
                "low",
                false,
                new GeoPoint(-6.890700, 107.610850, null),
                null,
                null,
                null,
                null,
                25.0,
                new CameraAnchorConfidence(
                        35,
                        "low",
                        List.of("gps_accuracy_low", "orientation_missing"),
                        List.of("recapture_with_better_gps", "calibrate_compass")));
    }

    private CameraAnchor arReadyAnchor() {
        return new CameraAnchor(
                "geo",
                "high",
                true,
                new GeoPoint(-6.890720, 107.610900, 743.0),
                42.0,
                42.0,
                -5.0,
                1.0,
                4.0,
                new CameraAnchorConfidence(
                        86,
                        "high",
                        List.of("gps_accuracy_high", "orientation_heading_and_compass"),
                        List.of()));
    }
}
