package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchorConfidence;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimap;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraMinimapViewportsTest {
    @Test
    void buildsHeadingUpMinimapViewport() {
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(100.0, 348.0),
                summary(4, 1, 0, 1, 0),
                List.of(
                        layer("people", dot("people", "presence", "user_rooftop", "avatar", 20.0, 0.2,
                                "near", "seed", "message", "/messaging/threads?participantId=user_rooftop")),
                        layer("memories", dot("memories", "memory", "memory_rooftop", "photo", 20.0, 0.2,
                                "near", "seed", "open", "/memories/memory_rooftop")),
                        layer("safety", dot("safety", "safety_zone", "zone_restricted", null, 5.0, 0.05,
                                "near", "seed", "blocked", "/safety/zones/users/viewer"))),
                3);

        assertEquals("heading_up", minimap.projectionMode());
        assertEquals(-6.890620, minimap.center().latitude());
        assertEquals(100.0, minimap.radiusMeters());
        assertEquals(348.0, minimap.orientationDegrees());
        assertEquals(12.0, minimap.northRelativeBearingDegrees());
        assertEquals(0.21, minimap.northX());
        assertEquals(-0.98, minimap.northY());
        assertEquals(3, minimap.rings().size());
        assertEquals(25.0, minimap.rings().getFirst().radiusMeters());
        assertEquals(0.25, minimap.rings().getFirst().radiusRatio());
        assertEquals("25 m", minimap.rings().getFirst().label());
        assertEquals(100.0, minimap.rings().get(2).radiusMeters());
        assertEquals(3, minimap.visibleDotCount());
        assertEquals(4, minimap.totalAvailableDotCount());
        assertEquals(1, minimap.perimeterDotCount());
        assertFalse(minimap.hasTruncatedLayers());
        assertEquals(3, minimap.pins().size());
        assertEquals("zone_restricted", minimap.pins().getFirst().targetId());
        assertEquals("safety_zone", minimap.pins().getFirst().displayMode());
        assertEquals(1000, minimap.pins().getFirst().priority());
        assertEquals("/safety/zones/users/viewer", minimap.pins().getFirst().href());
        assertEquals("user_rooftop", minimap.pins().get(1).targetId());
        assertEquals("avatar", minimap.pins().get(1).displayMode());
        assertEquals("public", minimap.pins().get(1).visibility());
        assertEquals("visible", minimap.pins().get(1).visibilityReason());
        assertEquals("https://cdn.jezaku.local/user_rooftop.jpg", minimap.pins().get(1).thumbnailUrl());
        assertEquals("memory_rooftop", minimap.pins().get(2).targetId());
        assertEquals("media_memory_rooftop", minimap.pins().get(2).mediaId());
        assertEquals("ar_photo", minimap.pins().get(2).displayMode());
        assertTrue(minimap.pins().get(2).publicMemoryEligible());
        assertEquals("high", minimap.pins().get(2).anchor().quality());
        assertTrue(minimap.pins().get(2).anchor().arReady());
        assertEquals("high", minimap.pins().get(2).anchor().confidence().level());
        assertTrue(minimap.pins().get(2).anchor().confidence().score() >= 80);
        assertTrue(minimap.pins().get(2).anchor().confidence().reasons().contains("gps_accuracy_high"));
        assertTrue(minimap.pins().get(2).anchor().confidence().recommendedActions().isEmpty());
        assertEquals(1, minimap.clusters().size());
        assertEquals("cluster_people_user_rooftop", minimap.clusters().getFirst().clusterId());
        assertEquals(0.2, minimap.clusters().getFirst().x());
        assertEquals(0.0, minimap.clusters().getFirst().y());
        assertEquals(2, minimap.clusters().getFirst().count());
        assertEquals(0, minimap.clusters().getFirst().safetyCount());
        assertEquals(1, minimap.clusters().getFirst().peopleCount());
        assertEquals(1, minimap.clusters().getFirst().memoryCount());
        assertEquals(0, minimap.clusters().getFirst().otherCount());
        assertFalse(minimap.clusters().getFirst().perimeter());
        assertEquals(600, minimap.clusters().getFirst().priority());
        assertEquals("2 nearby", minimap.clusters().getFirst().label());
        assertEquals(3, minimap.layerControls().size());
        assertEquals("safety", minimap.layerControls().getFirst().layer());
        assertEquals("Safety", minimap.layerControls().getFirst().label());
        assertEquals("safety_zone", minimap.layerControls().getFirst().displayMode());
        assertEquals("ready", minimap.layerControls().getFirst().status());
        assertTrue(minimap.layerControls().getFirst().visibleByDefault());
        assertTrue(minimap.layerControls().getFirst().toggleable());
        assertEquals(1, minimap.layerControls().getFirst().count());
        assertEquals(900, minimap.layerControls().getFirst().priority());
        assertEquals("people", minimap.layerControls().get(1).layer());
        assertEquals("memories", minimap.layerControls().get(2).layer());
        assertEquals(3, minimap.layerClips().size());
        assertEquals("safety", minimap.layerClips().getFirst().layer());
        assertEquals(0, minimap.layerClips().getFirst().pinLimit());
        assertEquals(1, minimap.layerClips().getFirst().availablePinCount());
        assertEquals(1, minimap.layerClips().getFirst().visiblePinCount());
        assertFalse(minimap.layerClips().getFirst().clipped());
        assertFalse(minimap.hasClippedPins());
        assertEquals(0, minimap.clippedPinCount());
        assertEquals(5, minimap.badges().size());
        assertEquals("safety", minimap.badges().getFirst().type());
        assertEquals("critical", minimap.badges().getFirst().severity());
        assertEquals(1, minimap.badges().getFirst().count());
        assertEquals(1000, minimap.badges().getFirst().priority());
        assertEquals("people", minimap.badges().get(1).type());
        assertEquals(1, minimap.badges().get(1).count());
        assertEquals("ar_ready_memories", minimap.badges().get(2).type());
        assertEquals("AR Ready", minimap.badges().get(2).label());
        assertEquals("active", minimap.badges().get(2).severity());
        assertEquals(1, minimap.badges().get(2).count());
        assertEquals("memories", minimap.badges().get(3).type());
        assertEquals("perimeter", minimap.badges().get(4).type());
    }

    @Test
    void clipsPinsPerLayerForCompactMinimap() {
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(100.0, 0.0),
                summary(3, 0, 0, 1, 0),
                List.of(
                        layer("people", List.of(
                                dot("people", "presence", "friend_alpha", "avatar", 10.0, 0.1,
                                        "near", "seed", "message", "/messaging/threads?participantId=friend_alpha"),
                                dot("people", "presence", "friend_beta", "avatar", 12.0, 0.12,
                                        "near", "seed", "message", "/messaging/threads?participantId=friend_beta"))),
                        layer("memories", dot("memories", "memory", "memory_alpha", "photo", 10.0, 0.1,
                                "near", "seed", "open", "/memories/memory_alpha"))),
                3,
                1);

        assertEquals(2, minimap.pins().size());
        assertEquals("friend_alpha", minimap.pins().getFirst().targetId());
        assertEquals("memory_alpha", minimap.pins().get(1).targetId());
        assertTrue(minimap.hasClippedPins());
        assertEquals(1, minimap.clippedPinCount());
        assertEquals(2, minimap.layerClips().size());
        assertEquals("people", minimap.layerClips().getFirst().layer());
        assertEquals(1, minimap.layerClips().getFirst().pinLimit());
        assertEquals(2, minimap.layerClips().getFirst().availablePinCount());
        assertEquals(1, minimap.layerClips().getFirst().visiblePinCount());
        assertEquals(1, minimap.layerClips().getFirst().clippedPinCount());
        assertTrue(minimap.layerClips().getFirst().clipped());
        assertEquals("memories", minimap.layerClips().get(1).layer());
        assertEquals(1, minimap.layerClips().get(1).availablePinCount());
        assertEquals(1, minimap.layerClips().get(1).visiblePinCount());
        assertFalse(minimap.layerClips().get(1).clipped());
        assertEquals(1, minimap.clusters().size());
        assertEquals(2, minimap.clusters().getFirst().count());
        var hiddenBadge = minimap.badges().stream()
                .filter(badge -> "hidden".equals(badge.type()))
                .findFirst()
                .orElseThrow();
        assertEquals(1, hiddenBadge.count());
    }

    @Test
    void downgradesArReadyMemoryPinWithoutPublicEligibleMedia() {
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(100.0, 0.0),
                summary(1, 0, 0),
                List.of(layer("memories", memoryDot("memory_pending", false))),
                1);

        assertEquals(1, minimap.pins().size());
        assertEquals("memory_pending", minimap.pins().getFirst().targetId());
        assertEquals("media_memory_pending", minimap.pins().getFirst().mediaId());
        assertEquals("photo_hint", minimap.pins().getFirst().displayMode());
        assertFalse(minimap.pins().getFirst().publicMemoryEligible());
        assertTrue(minimap.pins().getFirst().anchor().arReady());
    }

    @Test
    void reportsTruncatedViewportAndScaledRings() {
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(80.0, 0.0),
                summary(12, 1, 1),
                List.of(layer("people", dot("people", "presence", "perimeter_user", "avatar", 80.0, 1.0,
                        "perimeter", "live_session", "message", "/messaging/threads?participantId=perimeter_user"))),
                2);

        assertEquals(0.0, minimap.northRelativeBearingDegrees());
        assertEquals(0.0, minimap.northX());
        assertEquals(-1.0, minimap.northY());
        assertEquals(20.0, minimap.rings().getFirst().radiusMeters());
        assertEquals(40.0, minimap.rings().get(1).radiusMeters());
        assertEquals(80.0, minimap.rings().get(2).radiusMeters());
        assertEquals(2, minimap.visibleDotCount());
        assertEquals(12, minimap.totalAvailableDotCount());
        assertTrue(minimap.hasTruncatedLayers());
        assertEquals(1, minimap.pins().size());
        assertTrue(minimap.clusters().isEmpty());
        assertTrue(minimap.pins().getFirst().perimeter());
        assertEquals(700, minimap.pins().getFirst().priority());
        assertEquals(1, minimap.layerControls().size());
        assertEquals("people", minimap.layerControls().getFirst().layer());
        assertEquals(1, minimap.layerControls().getFirst().count());
        assertFalse(minimap.layerControls().getFirst().truncated());
        assertEquals(3, minimap.badges().size());
        assertEquals("live_people", minimap.badges().getFirst().type());
        assertEquals("active", minimap.badges().getFirst().severity());
        assertEquals("people", minimap.badges().get(1).type());
        assertEquals("perimeter", minimap.badges().get(2).type());
    }

    @Test
    void reportsHiddenBadgeForTruncatedLayers() {
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(100.0, 0.0),
                summary(4, 0, 1),
                List.of(new CameraLayer(
                        "memories",
                        "ready",
                        "",
                        CameraLayerSources.seed(Instant.EPOCH),
                        1,
                        4,
                        true,
                        new CameraLayerSummary(20.0, 20.0, 0, 0, 0, 1, 0, 0, 0),
                        List.of(dot("memories", "memory", "memory_one", "photo", 20.0, 0.2,
                                "near", "seed", "open", "/memories/memory_one")))),
                1);

        assertEquals("memories", minimap.badges().getFirst().type());
        assertTrue(minimap.clusters().isEmpty());
        assertEquals("hidden", minimap.badges().get(1).type());
        assertEquals(3, minimap.badges().get(1).count());
        assertEquals("info", minimap.badges().get(1).severity());
    }

    @Test
    void carriesPeopleVisibilityReportIntoMinimap() {
        CameraVisibilityReport visibility = new CameraVisibilityReport(
                "people",
                "social_audience",
                "social",
                "healthy",
                false,
                4,
                1,
                3,
                List.of(new CameraVisibilityReasonCount("blocked", 1),
                        new CameraVisibilityReasonCount("visibility_hidden", 2)));
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(100.0, 0.0),
                summary(1, 0, 0),
                List.of(new CameraLayer(
                        "people",
                        "ready",
                        "",
                        CameraLayerSources.http("presence_service", Instant.EPOCH),
                        1,
                        1,
                        false,
                        visibility,
                        new CameraLayerSummary(20.0, 20.0, 0, 0, 1, 0, 0, 0, 0),
                        List.of(dot("people", "presence", "friend_one", "avatar", 20.0, 0.2,
                                "near", "presence_service", "message", "/messaging/threads?participantId=friend_one")))),
                1);

        assertEquals(1, minimap.visibilityReports().size());
        assertEquals("people", minimap.visibilityReports().getFirst().layer());
        assertEquals("social_audience", minimap.visibilityReports().getFirst().mode());
        assertEquals(3, minimap.visibilityReports().getFirst().hiddenCandidateCount());
        assertEquals("hidden", minimap.badges().get(1).type());
        assertEquals(3, minimap.badges().get(1).count());
    }

    @Test
    void reportsAnchorRefinementBadgeBeforeArReadyAndMemoryBadges() {
        CameraMinimap minimap = CameraMinimapViewports.from(
                telemetry(100.0, 0.0),
                summary(2, 0, 0, 1, 2),
                List.of(layer("memories", dot("memories", "memory", "memory_one", "photo", 20.0, 0.2,
                        "near", "seed", "open", "/memories/memory_one"))),
                1);

        assertEquals("anchor_refinement", minimap.badges().getFirst().type());
        assertEquals("Refine", minimap.badges().getFirst().label());
        assertEquals("warning", minimap.badges().getFirst().severity());
        assertEquals(2, minimap.badges().getFirst().count());
        assertEquals(500, minimap.badges().getFirst().priority());
        assertEquals("ar_ready_memories", minimap.badges().get(1).type());
        assertEquals("memories", minimap.badges().get(2).type());
    }

    private CameraTelemetry telemetry(double radiusMeters, double orientationDegrees) {
        return new CameraTelemetry(
                "viewer",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                orientationDegrees,
                orientationDegrees,
                orientationDegrees,
                0.6,
                null,
                radiusMeters,
                Instant.EPOCH);
    }

    private CameraContextSummary summary(int totalAvailableDots, int perimeterCount, int truncatedLayerCount) {
        return summary(totalAvailableDots, perimeterCount, truncatedLayerCount, 0, 0);
    }

    private CameraContextSummary summary(
            int totalAvailableDots,
            int perimeterCount,
            int truncatedLayerCount,
            int arReadyMemoryCount,
            int needsRefinementMemoryCount) {
        return new CameraContextSummary(
                3,
                3,
                totalAvailableDots,
                truncatedLayerCount,
                0,
                0,
                0,
                perimeterCount,
                0,
                1,
                1,
                arReadyMemoryCount,
                needsRefinementMemoryCount,
                needsRefinementMemoryCount,
                0,
                0,
                0,
                0,
                null,
                10.0,
                80.0);
    }

    private CameraLayer layer(String layer, CameraDot dot) {
        return layer(layer, List.of(dot));
    }

    private CameraLayer layer(String layer, List<CameraDot> dots) {
        double nearestDistanceMeters = dots.stream()
                .mapToDouble(CameraDot::distanceMeters)
                .min()
                .orElse(0.0);
        double farthestDistanceMeters = dots.stream()
                .mapToDouble(CameraDot::distanceMeters)
                .max()
                .orElse(0.0);
        return new CameraLayer(
                layer,
                "ready",
                "",
                CameraLayerSources.seed(Instant.EPOCH),
                dots.size(),
                dots.size(),
                false,
                new CameraLayerSummary(
                        nearestDistanceMeters,
                        farthestDistanceMeters,
                        dots.stream().mapToInt(this::perimeter).sum(),
                        0,
                        dots.size(),
                        0,
                        memoryLayer(layer) ? dots.size() : 0,
                        0,
                        0),
                dots);
    }

    private boolean memoryLayer(String layer) {
        return "memories".equals(layer);
    }

    private int perimeter(CameraDot dot) {
        return dot.distanceRatio() >= 1.0 || "perimeter".equals(dot.distanceBucket()) ? 1 : 0;
    }

    private CameraDot dot(
            String layer,
            String targetType,
            String targetId,
            String displayMode,
            double distanceMeters,
            double distanceRatio,
            String distanceBucket,
            String source,
            String actionType,
            String href) {
        return new CameraDot(
                layer,
                targetType,
                targetId,
                targetId + "_owner",
                "memories".equals(layer) ? "media_" + targetId : null,
                source,
                "public",
                "visible",
                null,
                0,
                null,
                distanceBucket,
                "fresh",
                targetId,
                "",
                null,
                "https://cdn.jezaku.local/" + targetId + ".jpg",
                "memories".equals(layer) ? "active" : null,
                "memories".equals(layer) ? "approved" : null,
                "memories".equals(layer) ? true : null,
                "memories".equals(layer) ? true : null,
                anchor(layer),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                null,
                null,
                distanceMeters,
                distanceRatio,
                0.0,
                0.0,
                distanceRatio,
                0.0,
                null,
                Instant.EPOCH,
                List.of(new CameraAction(actionType, actionType, href)));
    }

    private CameraDot memoryDot(String targetId, boolean publicMemoryEligible) {
        return new CameraDot(
                "memories",
                "memory",
                targetId,
                targetId + "_owner",
                "media_" + targetId,
                "seed",
                "public",
                null,
                0,
                null,
                "near",
                "fresh",
                targetId,
                "",
                null,
                "https://cdn.jezaku.local/" + targetId + ".jpg",
                "active",
                publicMemoryEligible ? "approved" : "pending",
                true,
                publicMemoryEligible,
                anchor("memories"),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                null,
                null,
                20.0,
                0.2,
                0.0,
                0.0,
                0.2,
                0.0,
                null,
                Instant.EPOCH,
                List.of(new CameraAction("open", "open", "/memories/" + targetId)));
    }

    private CameraAnchor anchor(String layer) {
        if (!"memories".equals(layer)) {
            return null;
        }
        return new CameraAnchor(
                "geo",
                "high",
                true,
                new GeoPoint(-6.890620, 107.610790, 742.0),
                91.0,
                90.0,
                -7.5,
                1.0,
                4.0,
                new CameraAnchorConfidence(
                        98,
                        "high",
                        List.of(
                                "anchor_type_geo",
                                "gps_accuracy_high",
                                "orientation_heading_and_compass",
                                "altitude_present",
                                "pose_pitch_and_roll"),
                        List.of()));
    }
}
