package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraAdvisory;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class CameraContextSummariesTest {
    @Test
    void summarizesEmptyContext() {
        CameraContextSummary summary = CameraContextSummaries.from(List.of(), List.of());

        assertEquals(0, summary.layerCount());
        assertEquals(0, summary.readyLayerCount());
        assertEquals(0, summary.totalAvailableDots());
        assertEquals(0, summary.truncatedLayerCount());
        assertEquals(0, summary.visibilityReportCount());
        assertEquals(0, summary.hiddenVisibilityCandidateCount());
        assertEquals(0, summary.visibilityAudienceAttentionLayerCount());
        assertEquals(0, summary.liveCount());
        assertEquals(0, summary.arReadyMemoryCount());
        assertEquals(0, summary.lowConfidenceMemoryCount());
        assertEquals(0, summary.needsRefinementMemoryCount());
        assertEquals(0, summary.criticalAdvisoryCount());
        assertEquals(0, summary.warningAdvisoryCount());
        assertEquals(0, summary.infoAdvisoryCount());
        assertEquals(0, summary.blockingAdvisoryCount());
        assertNull(summary.highestAdvisoryPriority());
        assertNull(summary.nearestDistanceMeters());
        assertNull(summary.farthestDistanceMeters());
    }

    @Test
    void summarizesLayersAndAdvisories() {
        CameraLayer people = layer(
                "people",
                "ready",
                2,
                4,
                true,
                new CameraLayerSummary(10.0, 30.0, 1, 2, 2, 0, 0, 0, 0),
                visibility("people", "healthy", false, 4, 1));
        CameraLayer memories = layer(
                "memories",
                "unavailable",
                1,
                1,
                false,
                new CameraLayerSummary(15.0, 80.0, 0, 0, 0, 1, 2, 1, 1),
                visibility("memories", "degraded", true, 3, 2));
        List<CameraAdvisory> advisories = List.of(
                advisory("critical", "blocking_banner", 1000),
                advisory("warning", "banner", 700),
                advisory("info", "hint", 100));

        CameraContextSummary summary = CameraContextSummaries.from(List.of(people, memories), advisories);

        assertEquals(2, summary.layerCount());
        assertEquals(1, summary.readyLayerCount());
        assertEquals(5, summary.totalAvailableDots());
        assertEquals(1, summary.truncatedLayerCount());
        assertEquals(2, summary.visibilityReportCount());
        assertEquals(3, summary.hiddenVisibilityCandidateCount());
        assertEquals(1, summary.visibilityAudienceAttentionLayerCount());
        assertEquals(1, summary.perimeterCount());
        assertEquals(2, summary.liveCount());
        assertEquals(2, summary.freshCount());
        assertEquals(1, summary.staticCount());
        assertEquals(2, summary.arReadyMemoryCount());
        assertEquals(1, summary.lowConfidenceMemoryCount());
        assertEquals(1, summary.needsRefinementMemoryCount());
        assertEquals(1, summary.criticalAdvisoryCount());
        assertEquals(1, summary.warningAdvisoryCount());
        assertEquals(1, summary.infoAdvisoryCount());
        assertEquals(1, summary.blockingAdvisoryCount());
        assertEquals(1000, summary.highestAdvisoryPriority());
        assertEquals(10.0, summary.nearestDistanceMeters());
        assertEquals(80.0, summary.farthestDistanceMeters());
    }

    private CameraAdvisory advisory(String severity, String displayMode, int priority) {
        return new CameraAdvisory(
                severity,
                priority,
                displayMode,
                "safety",
                "safety_zone",
                "zone",
                "Title",
                "Message",
                "blocked",
                "/safety/zones",
                12.0);
    }

    private CameraLayer layer(
            String layer,
            String status,
            int count,
            int totalAvailable,
            boolean truncated,
            CameraLayerSummary summary) {
        return layer(layer, status, count, totalAvailable, truncated, summary, null);
    }

    private CameraLayer layer(
            String layer,
            String status,
            int count,
            int totalAvailable,
            boolean truncated,
            CameraLayerSummary summary,
            CameraVisibilityReport visibility) {
        return new CameraLayer(
                layer,
                status,
                "",
                CameraLayerSources.seed(java.time.Instant.EPOCH),
                count,
                totalAvailable,
                truncated,
                visibility,
                summary,
                List.of());
    }

    private CameraVisibilityReport visibility(
            String layer,
            String audienceHealth,
            boolean audienceFallback,
            int candidateCount,
            int hiddenCount) {
        return new CameraVisibilityReport(
                layer,
                "camera_local",
                "seed",
                audienceHealth,
                audienceFallback,
                candidateCount,
                candidateCount - hiddenCount,
                hiddenCount,
                List.of(new CameraVisibilityReasonCount("visibility_hidden", hiddenCount)));
    }
}
