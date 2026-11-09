package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextRefresh;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraOpsHealthReportsTest {
    private static final Instant NOW = Instant.parse("2026-06-04T00:00:00Z");

    @Test
    void reportsHealthySeededLayers() {
        CameraOpsHealthResponse report = CameraOpsHealthReports.from(context(List.of(
                layer("safety", "ready", CameraLayerSources.seed(NOW.minusSeconds(2)), false),
                layer("people", "ready", CameraLayerSources.seed(NOW.minusSeconds(1)), false))), NOW);

        assertEquals("healthy", report.status());
        assertEquals(100, report.score());
        assertEquals(2, report.layerCount());
        assertEquals(2, report.healthyLayerCount());
        assertEquals(0, report.degradedLayerCount());
        assertEquals(0, report.criticalLayerCount());
        assertEquals(0, report.fallbackLayerCount());
        assertEquals(0, report.staleLayerCount());
        assertTrue(report.issues().isEmpty());
        assertTrue(report.advisories().isEmpty());
        assertEquals("healthy", report.layers().getFirst().health());
        assertEquals(2, report.layers().getFirst().sourceAgeSeconds());
    }

    @Test
    void reportsFallbackAsDegraded() {
        CameraLayerSource source = CameraLayerSources.fallback(
                "http",
                "seed",
                new IllegalStateException("presence offline"),
                NOW.minusSeconds(3));

        CameraOpsHealthResponse report = CameraOpsHealthReports.from(context(List.of(
                layer("people", "ready", source, false))), NOW);

        assertEquals("degraded", report.status());
        assertEquals(85, report.score());
        assertEquals(0, report.healthyLayerCount());
        assertEquals(1, report.degradedLayerCount());
        assertEquals(0, report.criticalLayerCount());
        assertEquals(1, report.fallbackLayerCount());
        assertEquals(0, report.unavailableLayerCount());
        assertEquals(0, report.staleLayerCount());
        assertTrue(report.issues().contains("fallback_active"));
        assertTrue(report.recommendedActions().contains("restore_http_source"));
        assertEquals(1, report.advisories().size());
        assertEquals("warning", report.advisories().getFirst().severity());
        assertEquals("hint", report.advisories().getFirst().displayMode());
        assertEquals("people", report.advisories().getFirst().layer());
        assertEquals("layer", report.advisories().getFirst().targetType());
        assertEquals("People layer needs attention", report.advisories().getFirst().title());
        assertEquals("People layer is using fallback data.", report.advisories().getFirst().message());
        assertEquals("restore_http_source", report.advisories().getFirst().actionType());
        assertEquals("/camera/ops/health?viewerId=viewer&lat=-6.89062&lng=107.61079"
                + "&altitudeMeters=742.0&headingDegrees=92.0&compassDegrees=88.0"
                + "&speedMetersPerSecond=1.5&radiusMeters=100.0&layers=people",
                report.advisories().getFirst().href());
        assertFalse(report.layers().getFirst().stale());
        assertEquals("IllegalStateException", report.layers().getFirst().source().fallbackReason());
    }

    @Test
    void reportsAudienceVisibilityFallbackAsDegraded() {
        CameraOpsHealthResponse report = CameraOpsHealthReports.from(context(List.of(
                layer(
                        "people",
                        "ready",
                        CameraLayerSources.seed(NOW.minusSeconds(1)),
                        false,
                        visibility("social_audience", "social", "degraded", true)))), NOW);

        assertEquals("degraded", report.status());
        assertEquals(85, report.score());
        assertEquals(0, report.healthyLayerCount());
        assertEquals(1, report.degradedLayerCount());
        assertEquals(0, report.criticalLayerCount());
        assertEquals(0, report.fallbackLayerCount());
        assertTrue(report.issues().contains("visibility_audience_fallback"));
        assertTrue(report.issues().contains("visibility_audience_degraded"));
        assertTrue(report.recommendedActions().contains("restore_social_audience_access"));
        assertEquals("social_audience", report.layers().getFirst().visibility().mode());
        assertEquals("degraded", report.layers().getFirst().visibility().audienceHealth());
        assertEquals(1, report.advisories().size());
        assertEquals("People layer needs attention", report.advisories().getFirst().title());
        assertEquals("People layer audience visibility is using fallback data.",
                report.advisories().getFirst().message());
        assertEquals("restore_social_audience_access", report.advisories().getFirst().actionType());
    }

    @Test
    void reportsCriticalAudienceVisibilityWithoutCallingTheLayerOffline() {
        CameraOpsHealthResponse report = CameraOpsHealthReports.from(context(List.of(
                layer(
                        "people",
                        "ready",
                        CameraLayerSources.seed(NOW.minusSeconds(1)),
                        false,
                        visibility("social_audience", "social", "critical", false)))), NOW);

        assertEquals("critical", report.status());
        assertEquals(65, report.score());
        assertEquals(0, report.healthyLayerCount());
        assertEquals(0, report.degradedLayerCount());
        assertEquals(1, report.criticalLayerCount());
        assertTrue(report.issues().contains("visibility_audience_critical"));
        assertTrue(report.recommendedActions().contains("restore_social_audience_access"));
        assertEquals("critical", report.layers().getFirst().health());
        assertEquals("critical", report.layers().getFirst().visibility().audienceHealth());
        assertEquals("People layer needs attention", report.advisories().getFirst().title());
        assertEquals("People layer audience visibility is critical.", report.advisories().getFirst().message());
    }

    @Test
    void reportsMemoryAnchorQualityAsDegradedWithoutCallingTheSourceUnhealthy() {
        CameraOpsHealthResponse report = CameraOpsHealthReports.from(context(List.of(
                layer(
                        "memories",
                        "ready",
                        CameraLayerSources.seed(NOW.minusSeconds(1)),
                        false,
                        null,
                        new CameraLayerSummary(12.0, 42.0, 0, 0, 0, 2, 1, 1, 2)))), NOW);

        assertEquals("degraded", report.status());
        assertEquals(85, report.score());
        assertEquals(0, report.healthyLayerCount());
        assertEquals(1, report.degradedLayerCount());
        assertEquals(0, report.criticalLayerCount());
        assertEquals(0, report.fallbackLayerCount());
        assertEquals(0, report.unavailableLayerCount());
        assertTrue(report.issues().contains("memory_anchor_refinement_needed"));
        assertTrue(report.issues().contains("memory_anchor_low_confidence"));
        assertFalse(report.issues().contains("source_unhealthy"));
        assertTrue(report.recommendedActions().contains("review_anchor"));
        assertEquals("degraded", report.layers().getFirst().health());
        assertEquals("Memories layer needs attention", report.advisories().getFirst().title());
        assertEquals("Memories layer has memory anchors needing refinement.",
                report.advisories().getFirst().message());
        assertEquals("review_anchor", report.advisories().getFirst().actionType());
    }

    @Test
    void reportsStaleAndUnavailableLayers() {
        CameraOpsHealthResponse report = CameraOpsHealthReports.from(context(List.of(
                layer("people", "ready", CameraLayerSources.seed(NOW.minusSeconds(20)), false),
                layer("memories", "unavailable", CameraLayerSources.unavailable("memories", NOW), true))), NOW);

        assertEquals("critical", report.status());
        assertEquals(40, report.score());
        assertEquals(0, report.healthyLayerCount());
        assertEquals(1, report.degradedLayerCount());
        assertEquals(1, report.criticalLayerCount());
        assertEquals(1, report.unavailableLayerCount());
        assertEquals(1, report.staleLayerCount());
        assertEquals(1, report.truncatedLayerCount());
        assertTrue(report.issues().contains("source_stale"));
        assertTrue(report.issues().contains("layer_unavailable"));
        assertTrue(report.issues().contains("source_unhealthy"));
        assertTrue(report.issues().contains("layer_truncated"));
        assertTrue(report.recommendedActions().contains("refresh_camera_context"));
        assertTrue(report.recommendedActions().contains("restore_memories_layer"));
        assertTrue(report.recommendedActions().contains("restore_memories_source"));
        assertTrue(report.recommendedActions().contains("raise_limit_per_layer_or_page_results"));
        assertEquals(2, report.advisories().size());
        assertEquals("critical", report.advisories().getFirst().severity());
        assertEquals("banner", report.advisories().getFirst().displayMode());
        assertEquals("memories", report.advisories().getFirst().layer());
        assertEquals("Memories layer offline", report.advisories().getFirst().title());
        assertEquals("Memories layer is unavailable.", report.advisories().getFirst().message());
        assertEquals("restore_memories_layer", report.advisories().getFirst().actionType());
        assertEquals("warning", report.advisories().get(1).severity());
        assertEquals("people", report.advisories().get(1).layer());
        assertEquals("People layer data is stale.", report.advisories().get(1).message());
    }

    @Test
    void fallsBackToLayerOnlyAdvisoryHrefWhenTelemetryIsMissing() {
        CameraLayerSource source = CameraLayerSources.fallback(
                "http",
                "seed",
                new IllegalStateException("presence offline"),
                NOW.minusSeconds(3));

        CameraOpsHealthResponse report = CameraOpsHealthReports.from(contextWithoutTelemetry(List.of(
                layer("people", "ready", source, false))), NOW);

        assertEquals("/camera/ops/health?layers=people", report.advisories().getFirst().href());
    }

    private CameraContextResponse context(List<CameraLayer> layers) {
        return context(layers, new CameraTelemetry(
                "viewer",
                new GeoPoint(-6.89062, 107.61079, 742.0),
                92.0,
                88.0,
                90.0,
                1.5,
                null,
                100.0,
                NOW));
    }

    private CameraContextResponse contextWithoutTelemetry(List<CameraLayer> layers) {
        return context(layers, null);
    }

    private CameraContextResponse context(List<CameraLayer> layers, CameraTelemetry telemetry) {
        CameraContextSummary summary = CameraContextSummaries.from(layers, List.of());
        return new CameraContextResponse(
                "viewer",
                telemetry,
                layers.stream().mapToInt(CameraLayer::count).sum(),
                0,
                summary,
                null,
                new CameraContextRefresh(10, 10, null, "idle"),
                null,
                List.of(),
                layers,
                NOW);
    }

    private CameraLayer layer(String name, String status, CameraLayerSource source, boolean truncated) {
        return layer(name, status, source, truncated, null);
    }

    private CameraLayer layer(
            String name,
            String status,
            CameraLayerSource source,
            boolean truncated,
            CameraVisibilityReport visibility) {
        return layer(name, status, source, truncated, visibility, CameraLayerSummaries.from(List.of()));
    }

    private CameraLayer layer(
            String name,
            String status,
            CameraLayerSource source,
            boolean truncated,
            CameraVisibilityReport visibility,
            CameraLayerSummary summary) {
        return new CameraLayer(
                name,
                status,
                "",
                source,
                truncated ? 1 : 0,
                truncated ? 2 : 0,
                truncated,
                visibility,
                summary,
                List.of());
    }

    private CameraVisibilityReport visibility(
            String mode,
            String audienceSource,
            String audienceHealth,
            boolean audienceFallback) {
        return new CameraVisibilityReport(
                mode,
                audienceSource,
                audienceHealth,
                audienceFallback,
                3,
                2,
                1,
                List.of(new CameraVisibilityReasonCount("visibility_hidden", 1)));
    }
}
