package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyUser;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceProjection;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PeopleOverlayProviderTest {
    @Test
    void preservesUpstreamPresenceTruncationInPeopleLayer() {
        PeopleOverlayProvider provider = new PeopleOverlayProvider();
        provider.visibilityService = new CameraVisibilityService();
        provider.presenceClient = request -> {
            assertEquals(88.0, request.headingDegrees());
            assertEquals(90.0, request.compassDegrees());
            assertEquals(90.0, request.orientationDegrees());
            return Uni.createFrom().item(response(request.now()));
        };

        CameraLayer layer = provider.layer(new CameraOverlayQuery(
                "viewer",
                new GeoPoint(10.0, 20.0, 100.0),
                88.0,
                90.0,
                90.0,
                100.0,
                2,
                Instant.parse("2026-06-03T00:00:00Z")))
                .await().indefinitely();

        assertEquals("people", layer.layer());
        assertEquals("presence_service", layer.source().effectiveSource());
        assertEquals(true, layer.source().healthy());
        assertEquals(2, layer.count());
        assertEquals(5, layer.totalAvailable());
        assertTrue(layer.truncated());
        assertEquals("people", layer.visibility().layer());
        assertEquals("camera_local", layer.visibility().mode());
        assertEquals(2, layer.visibility().candidateCount());
        assertEquals(0, layer.visibility().hiddenCandidateCount());
    }

    @Test
    void usesPresenceServiceProjectionWhenAvailable() {
        PeopleOverlayProvider provider = new PeopleOverlayProvider();
        provider.visibilityService = new CameraVisibilityService();
        provider.presenceClient = request -> Uni.createFrom().item(projectedResponse(request.now()));

        CameraLayer layer = provider.layer(new CameraOverlayQuery(
                "viewer",
                new GeoPoint(10.0, 20.0, 100.0),
                88.0,
                90.0,
                90.0,
                100.0,
                5,
                Instant.parse("2026-06-03T00:00:00Z")))
                .await().indefinitely();

        var dot = layer.dots().getFirst();
        assertEquals(12.34, dot.distanceMeters());
        assertEquals(0.12, dot.distanceRatio());
        assertEquals("near", dot.distanceBucket());
        assertEquals(91.2, dot.bearingDegrees());
        assertEquals(1.2, dot.relativeBearingDegrees());
        assertEquals(0.03, dot.relativeX());
        assertEquals(-0.12, dot.relativeY());
        assertEquals(4.5, dot.altitudeDeltaMeters());
        assertEquals(42L, dot.ageSeconds());
        assertEquals(78L, dot.expiresInSeconds());
        assertEquals("recent", dot.freshnessState());
        assertEquals("friend", dot.visibilityReason());
        assertEquals("people", layer.visibility().layer());
        assertEquals("social_audience", layer.visibility().mode());
        assertEquals("social", layer.visibility().audienceSource());
        assertEquals(2, layer.visibility().hiddenCandidateCount());
        assertEquals("blocked", layer.visibility().hiddenReasons().getFirst().reason());
    }

    private CameraPresenceNearbyResponse response(Instant now) {
        return new CameraPresenceNearbyResponse(
                2,
                5,
                true,
                CameraLayerSources.http("presence_service", now),
                List.of(
                        new CameraPresenceNearbyUser(
                                "nearby_one",
                                "Nearby One",
                                "presence_service",
                                "",
                                new GeoPoint(10.0, 20.00010, 100.0),
                                null,
                                null,
                                "public",
                                "visible",
                                100,
                                "",
                                now.minusSeconds(5),
                                now.plusSeconds(120),
                                null),
                        new CameraPresenceNearbyUser(
                                "nearby_two",
                                "Nearby Two",
                                "presence_service",
                                "",
                                new GeoPoint(10.0, 20.00020, 100.0),
                                null,
                                null,
                                "public",
                                "visible",
                                100,
                                "",
                                now.minusSeconds(6),
                                now.plusSeconds(120),
                                null)));
    }

    private CameraPresenceNearbyResponse projectedResponse(Instant now) {
        return new CameraPresenceNearbyResponse(
                1,
                1,
                false,
                CameraLayerSources.http("presence_service", now),
                new CameraVisibilityReport(
                        "social_audience",
                        "social",
                        "healthy",
                        false,
                        3,
                        1,
                        2,
                        List.of(new CameraVisibilityReasonCount("blocked", 2))),
                List.of(new CameraPresenceNearbyUser(
                        "projected_nearby",
                        "Projected Nearby",
                        "presence_service",
                        "",
                        new GeoPoint(10.0, 20.00900, 100.0),
                        null,
                        null,
                        "public",
                        "friend",
                        100,
                        "",
                        now.minusSeconds(1),
                        now.plusSeconds(120),
                        new CameraPresenceProjection(
                                12.34,
                                0.12,
                                "near",
                                91.2,
                                1.2,
                                0.03,
                                -0.12,
                                4.5,
                                42L,
                                78L,
                                "recent"))));
    }
}
