package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraAdvisory;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchorConfidence;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaEvent;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextRefresh;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CameraContextDeltaServiceTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    private final CameraContextDeltaService service = new CameraContextDeltaService();

    @Test
    void reportsEnteredClearedAndSettledContextSignals() {
        CameraContextDeltaResponse initial = service.delta(
                "session_delta",
                context(List.of(dot("people", "presence", "user_rooftop", 12.0)), List.of(advisory("zone_one"))),
                NOW);

        assertEquals(2, initial.count());
        assertEquals("first_sync", initial.resetReason());
        assertEquals(true, initial.baselineReset());
        assertEquals(1, initial.dotEnteredCount());
        assertEquals(1, initial.advisoryEventCount());
        assertEquals(0, initial.layerEventCount());
        assertEquals("advisory.active", initial.events().getFirst().type());
        assertEquals("dot.entered", initial.events().get(1).type());

        CameraContextDeltaResponse settled = service.delta(
                "session_delta",
                context(List.of(dot("people", "presence", "user_rooftop", 12.0)), List.of(advisory("zone_one"))),
                NOW.plusSeconds(1));

        assertEquals(0, settled.count());
        assertEquals(false, settled.baselineReset());
        assertEquals("", settled.resetReason());

        CameraContextDeltaResponse changed = service.delta(
                "session_delta",
                context(List.of(dot("people", "presence", "user_lens", 20.0)), List.of()),
                NOW.plusSeconds(2));

        assertEquals(3, changed.count());
        assertEquals(1, changed.dotEnteredCount());
        assertEquals(1, changed.dotLeftCount());
        assertEquals(0, changed.dotUpdatedCount());
        assertEquals(1, changed.advisoryEventCount());
        assertEquals("dot.entered", changed.events().getFirst().type());
        assertEquals("advisory.cleared", changed.events().get(1).type());
        assertEquals("dot.left", changed.events().get(2).type());
    }

    @Test
    void resetsBaselineWhenViewShapeChanges() {
        service.delta(
                "session_view_change",
                context(List.of(dot("people", "presence", "user_rooftop", 12.0)), List.of()),
                NOW);

        CameraContextDeltaResponse changedView = service.delta(
                "session_view_change",
                context(List.of(dot("memories", "memory", "memory_rooftop", 20.0)), List.of()),
                NOW.plusSeconds(1));

        assertEquals(true, changedView.baselineReset());
        assertEquals("view_changed", changedView.resetReason());
        assertEquals(1, changedView.count());
        assertEquals(1, changedView.dotEnteredCount());
        assertEquals(0, changedView.dotLeftCount());
        assertEquals("dot.entered", changedView.events().getFirst().type());
        assertEquals("memory_rooftop", changedView.events().getFirst().targetId());
    }

    @Test
    void limitsReturnedEventsWithoutDroppingTheFullBaseline() {
        CameraContextResponse context = context(List.of(
                dot("people", "presence", "user_near", 10.0),
                dot("people", "presence", "user_mid", 20.0),
                dot("people", "presence", "user_far", 30.0)), List.of());

        CameraContextDeltaResponse limited = service.delta("session_limited", context, NOW, 2);

        assertEquals(2, limited.count());
        assertEquals(3, limited.totalAvailableCount());
        assertEquals(true, limited.truncated());
        assertEquals(2, limited.dotEnteredCount());
        assertEquals("user_near", limited.events().getFirst().targetId());
        assertEquals("user_mid", limited.events().get(1).targetId());

        CameraContextDeltaResponse settled = service.delta("session_limited", context, NOW.plusSeconds(1), 2);
        assertEquals(0, settled.count());
        assertEquals(0, settled.totalAvailableCount());
        assertEquals(false, settled.truncated());
    }

    @Test
    void reportsUpdatedDotsForSemanticStateChanges() {
        service.delta(
                "session_dot_update",
                context(List.of(memoryDot(
                        "memory_rooftop",
                        18.0,
                        "near",
                        "static",
                        false,
                        "low",
                        false,
                        "processing",
                        "pending")), List.of()),
                NOW);

        CameraContextDeltaResponse changed = service.delta(
                "session_dot_update",
                context(List.of(memoryDot(
                        "memory_rooftop",
                        48.0,
                        "mid",
                        "fresh",
                        true,
                        "high",
                        true,
                        "ready",
                        "approved")), List.of()),
                NOW.plusSeconds(1));

        assertEquals(false, changed.baselineReset());
        assertEquals(1, changed.count());
        assertEquals(0, changed.dotEnteredCount());
        assertEquals(0, changed.dotLeftCount());
        assertEquals(1, changed.dotUpdatedCount());

        CameraContextDeltaEvent event = changed.events().getFirst();
        assertEquals("dot.updated", event.type());
        assertEquals("memory_rooftop", event.targetId());
        assertEquals("ar_photo", event.displayMode());
        assertEquals("mid", event.distanceBucket());
        assertEquals("fresh", event.freshnessState());
        assertEquals("high", event.anchorConfidenceLevel());
        assertEquals(true, event.anchorArReady());
        assertEquals(48.0, event.distanceMeters());
        assertEquals(18.0, event.previousDistanceMeters());
        assertEquals(List.of(
                "distance_bucket_changed",
                "freshness_changed",
                "display_mode_changed",
                "anchor_confidence_changed",
                "anchor_readiness_changed",
                "public_memory_eligibility_changed",
                "media_state_changed"), event.changeReasons());
    }

    @Test
    void reportsUpdatedDotsForVisibilityStateChanges() {
        service.delta(
                "session_dot_visibility",
                context(List.of(presenceDot("user_rooftop", 18.0, "public", "visible")), List.of()),
                NOW);

        CameraContextDeltaResponse changed = service.delta(
                "session_dot_visibility",
                context(List.of(presenceDot("user_rooftop", 18.0, "friends", "friend")), List.of()),
                NOW.plusSeconds(1));

        assertEquals(false, changed.baselineReset());
        assertEquals(1, changed.count());
        assertEquals(1, changed.dotUpdatedCount());

        CameraContextDeltaEvent event = changed.events().getFirst();
        assertEquals("dot.updated", event.type());
        assertEquals("user_rooftop", event.targetId());
        assertEquals("friends", event.visibility());
        assertEquals("friend", event.visibilityReason());
        assertEquals(List.of("visibility_changed", "visibility_reason_changed"), event.changeReasons());
    }

    @Test
    void reportsLayerSourceHealthChangesWithoutClientSideContextDiffing() {
        CameraDot dot = dot("people", "presence", "user_rooftop", 12.0);
        service.delta(
                "session_layer_health",
                context(List.of(dot), List.of(), CameraLayerSources.seed(NOW), "ready", false),
                NOW);

        CameraLayerSource fallbackSource = CameraLayerSources.fallback(
                "http",
                "seed",
                new IllegalStateException("presence offline"),
                NOW.plusSeconds(1));
        CameraContextDeltaResponse changed = service.delta(
                "session_layer_health",
                context(List.of(dot), List.of(), fallbackSource, "ready", false),
                NOW.plusSeconds(1));

        assertEquals(false, changed.baselineReset());
        assertEquals(1, changed.count());
        assertEquals(0, changed.dotEnteredCount());
        assertEquals(0, changed.dotLeftCount());
        assertEquals(0, changed.dotUpdatedCount());
        assertEquals(0, changed.advisoryEventCount());
        assertEquals(1, changed.layerEventCount());

        CameraContextDeltaEvent event = changed.events().getFirst();
        assertEquals("layer.health.changed", event.type());
        assertEquals("people", event.layer());
        assertEquals("layer", event.targetType());
        assertEquals("people", event.targetId());
        assertEquals("People layer", event.title());
        assertEquals("warning", event.severity());
        assertEquals("layer_health", event.displayMode());
        assertEquals(List.of(
                "source_requested_changed",
                "source_health_changed",
                "source_fallback_changed",
                "source_fallback_reason_changed"), event.changeReasons());
    }

    @Test
    void reportsLayerVisibilityReportChangesWithoutClientSideContextDiffing() {
        CameraDot dot = dot("people", "presence", "user_rooftop", 12.0);
        service.delta(
                "session_layer_visibility",
                context(
                        List.of(dot),
                        List.of(),
                        CameraLayerSources.seed(NOW),
                        "ready",
                        false,
                        visibilityReport(2, 1, "visibility_hidden")),
                NOW);

        CameraContextDeltaResponse changed = service.delta(
                "session_layer_visibility",
                context(
                        List.of(dot),
                        List.of(),
                        CameraLayerSources.seed(NOW),
                        "ready",
                        false,
                        visibilityReport(3, 2, "blocked")),
                NOW.plusSeconds(1));

        assertEquals(false, changed.baselineReset());
        assertEquals(1, changed.count());
        assertEquals(0, changed.dotUpdatedCount());
        assertEquals(1, changed.layerEventCount());

        CameraContextDeltaEvent event = changed.events().getFirst();
        assertEquals("layer.visibility.changed", event.type());
        assertEquals("people", event.layer());
        assertEquals("layer", event.targetType());
        assertEquals("people", event.targetId());
        assertEquals(List.of("visibility_report_changed"), event.changeReasons());
        assertEquals("people", event.visibilityReport().layer());
        assertEquals("social_audience", event.visibilityReport().mode());
        assertEquals(3, event.visibilityReport().candidateCount());
        assertEquals(2, event.visibilityReport().hiddenCandidateCount());
        assertEquals("blocked", event.visibilityReport().hiddenReasons().getFirst().reason());
    }

    @Test
    void ignoresDistanceJitterInsideSameSemanticState() {
        service.delta(
                "session_dot_jitter",
                context(List.of(memoryDot(
                        "memory_rooftop",
                        12.0,
                        "near",
                        "fresh",
                        true,
                        "high",
                        true,
                        "ready",
                        "approved")), List.of()),
                NOW);

        CameraContextDeltaResponse changed = service.delta(
                "session_dot_jitter",
                context(List.of(memoryDot(
                        "memory_rooftop",
                        18.0,
                        "near",
                        "fresh",
                        true,
                        "high",
                        true,
                        "ready",
                        "approved")), List.of()),
                NOW.plusSeconds(1));

        assertEquals(0, changed.count());
        assertEquals(0, changed.dotUpdatedCount());
    }

    @Test
    void clearDropsPreviousSnapshotSoNextDeltaStartsFresh() {
        CameraContextResponse context = context(
                List.of(dot("people", "presence", "user_rooftop", 12.0)),
                List.of());

        assertEquals(1, service.delta("session_clear", context, NOW).count());
        assertEquals(0, service.delta("session_clear", context, NOW.plusSeconds(1)).count());

        service.clear("session_clear");

        CameraContextDeltaResponse afterClear = service.delta("session_clear", context, NOW.plusSeconds(2));
        assertEquals(true, afterClear.baselineReset());
        assertEquals("first_sync", afterClear.resetReason());
        assertEquals(1, afterClear.count());
        assertEquals("dot.entered", afterClear.events().getFirst().type());
    }

    private CameraContextResponse context(List<CameraDot> dots, List<CameraAdvisory> advisories) {
        return context(dots, advisories, CameraLayerSources.seed(NOW), "ready", false);
    }

    private CameraContextResponse context(
            List<CameraDot> dots,
            List<CameraAdvisory> advisories,
            CameraLayerSource source,
            String status,
            boolean truncated) {
        return context(dots, advisories, source, status, truncated, null);
    }

    private CameraContextResponse context(
            List<CameraDot> dots,
            List<CameraAdvisory> advisories,
            CameraLayerSource source,
            String status,
            boolean truncated,
            CameraVisibilityReport visibility) {
        CameraLayer layer = new CameraLayer(
                dots.isEmpty() ? "memories" : dots.getFirst().layer(),
                status,
                "",
                source,
                dots.size(),
                truncated ? dots.size() + 1 : dots.size(),
                truncated,
                visibility,
                CameraLayerSummaries.from(dots),
                dots);
        CameraContextSummary summary = CameraContextSummaries.from(List.of(layer), advisories);
        return new CameraContextResponse(
                "viewer",
                telemetry(),
                dots.size(),
                advisories.size(),
                summary,
                null,
                new CameraContextRefresh(15, 15, null, "ambient"),
                CameraMinimapViewports.from(telemetry(), summary, List.of(layer), dots.size()),
                advisories,
                List.of(layer),
                NOW);
    }

    private CameraTelemetry telemetry() {
        return new CameraTelemetry(
                "viewer",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                0.0,
                0.0,
                0.0,
                null,
                null,
                100.0,
                NOW);
    }

    private CameraDot dot(String layer, String targetType, String targetId, double distanceMeters) {
        return new CameraDot(
                layer,
                targetType,
                targetId,
                "owner_" + targetId,
                null,
                "seed",
                "public",
                null,
                0,
                null,
                "near",
                "static",
                targetId,
                "",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                new GeoPoint(-6.890700, 107.610850, 742.0),
                null,
                null,
                distanceMeters,
                distanceMeters / 100.0,
                45.0,
                45.0,
                0.1,
                -0.1,
                0.0,
                NOW,
                List.of());
    }

    private CameraDot presenceDot(String targetId, double distanceMeters, String visibility, String visibilityReason) {
        return new CameraDot(
                "people",
                "presence",
                targetId,
                "owner_" + targetId,
                null,
                "seed",
                visibility,
                visibilityReason,
                null,
                0,
                null,
                "near",
                "static",
                targetId,
                "",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                new GeoPoint(-6.890700, 107.610850, 742.0),
                null,
                null,
                distanceMeters,
                distanceMeters / 100.0,
                45.0,
                45.0,
                0.1,
                -0.1,
                0.0,
                NOW,
                List.of());
    }

    private CameraVisibilityReport visibilityReport(int candidateCount, int hiddenCount, String reason) {
        return new CameraVisibilityReport(
                "people",
                "social_audience",
                "social",
                "healthy",
                false,
                candidateCount,
                candidateCount - hiddenCount,
                hiddenCount,
                List.of(new CameraVisibilityReasonCount(reason, hiddenCount)));
    }

    private CameraDot memoryDot(
            String targetId,
            double distanceMeters,
            String distanceBucket,
            String freshnessState,
            boolean publicMemoryEligible,
            String confidenceLevel,
            boolean arReady,
            String mediaStatus,
            String moderationStatus) {
        return new CameraDot(
                "memories",
                "memory",
                targetId,
                "owner_" + targetId,
                "media_" + targetId,
                "seed",
                "public",
                null,
                0,
                null,
                distanceBucket,
                freshnessState,
                targetId,
                "",
                "https://cdn.jezaku.local/" + targetId + ".jpg",
                "https://cdn.jezaku.local/" + targetId + "-thumb.jpg",
                mediaStatus,
                moderationStatus,
                true,
                publicMemoryEligible,
                new CameraAnchor(
                        "geo",
                        confidenceLevel,
                        arReady,
                        new GeoPoint(-6.890700, 107.610850, 742.0),
                        null,
                        null,
                        null,
                        null,
                        5.0,
                        new CameraAnchorConfidence(
                                "high".equals(confidenceLevel) ? 90 : 40,
                                confidenceLevel,
                                List.of(),
                                arReady ? List.of() : List.of("improve_gps"))),
                new GeoPoint(-6.890700, 107.610850, 742.0),
                null,
                null,
                distanceMeters,
                distanceMeters / 100.0,
                45.0,
                45.0,
                0.1,
                -0.1,
                0.0,
                NOW,
                List.of());
    }

    private CameraAdvisory advisory(String targetId) {
        return new CameraAdvisory(
                "warning",
                700,
                "banner",
                "safety",
                "safety_zone",
                targetId,
                "Safety nearby",
                "Slow down",
                "near_restricted_area",
                "/safety/zones/" + targetId,
                8.0);
    }
}
