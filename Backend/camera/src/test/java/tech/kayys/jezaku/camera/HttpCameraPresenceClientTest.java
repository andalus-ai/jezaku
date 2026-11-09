package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;

import java.net.URI;
import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class HttpCameraPresenceClientTest {
    @Test
    void buildsPresenceNearbyUriFromCameraOverlayRequest() {
        HttpCameraPresenceClient client = new HttpCameraPresenceClient(
                objectMapper(),
                Optional.of("http://presence.local/"),
                3);

        URI uri = client.presenceNearbyUri(new CameraPresenceNearbyRequest(
                "user current",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                88.0,
                90.0,
                90.0,
                100.0,
                25,
                Instant.parse("2026-06-03T00:00:00Z")));

        assertEquals(
                "http://presence.local/presence/nearby?lat=-6.89062&lng=107.61079"
                        + "&radiusMeters=100.0&limit=25&headingDegrees=88.0&compassDegrees=90.0"
                        + "&altitudeMeters=742.0&viewerId=user+current",
                uri.toString());
    }

    @Test
    void mapsPresenceNearbyResponseIntoCameraPresenceUsers() {
        HttpCameraPresenceClient client = new HttpCameraPresenceClient(
                objectMapper(),
                Optional.of("http://presence.local"),
                3);

        CameraPresenceNearbyResponse response = client.responseFromJson("""
                {
                  "viewerId": "user_current",
                  "radiusMeters": 100.0,
                  "count": 1,
                  "totalAvailableCount": 3,
                  "truncated": true,
                  "visibility": {
                    "mode": "social_audience",
                    "audienceSource": "social",
                    "audienceHealth": "healthy",
                    "audienceFallback": false,
                    "candidateCount": 4,
                    "visibleCandidateCount": 1,
                    "hiddenCandidateCount": 3,
                    "hiddenReasons": [
                      { "reason": "blocked", "count": 1 },
                      { "reason": "visibility_hidden", "count": 2 }
                    ]
                  },
                  "users": [
                    {
                      "userId": "user_rooftop",
                      "displayName": "Rooftop Friend",
                      "avatarUrl": "https://cdn.jezaku.local/avatars/rooftop.jpg",
                      "position": {
                        "latitude": -6.890580,
                        "longitude": 107.610970,
                        "altitudeMeters": 746.4
                      },
                      "headingDegrees": 87.0,
                      "compassDegrees": 87.0,
                      "visibility": "public",
                      "visibilityReason": "visible",
                      "shareRadiusMeters": 75,
                      "statusMessage": "Near the virtual wall",
                      "distanceMeters": 20.42,
                      "distanceRatio": 0.2,
                      "distanceBucket": "near",
                      "bearingDegrees": 77.2,
                      "relativeBearingDegrees": 89.2,
                      "relativeX": 0.2,
                      "relativeY": 0.0,
                      "altitudeDeltaMeters": 4.4,
                      "ageSeconds": 18,
                      "expiresInSeconds": 102,
                      "freshnessState": "fresh",
                      "observedAt": "2026-06-03T00:00:00Z",
                      "expiresAt": "2026-06-03T00:02:00Z"
                    }
                  ]
                }
                """, request());

        assertEquals(1, response.count());
        assertEquals(3, response.totalAvailableCount());
        assertEquals(true, response.truncated());
        assertEquals("http", response.source().requestedSource());
        assertEquals("presence_service", response.source().effectiveSource());
        assertEquals(true, response.source().healthy());
        assertEquals(false, response.source().fallback());
        assertEquals("social_audience", response.visibility().mode());
        assertEquals("social", response.visibility().audienceSource());
        assertEquals("healthy", response.visibility().audienceHealth());
        assertEquals(4, response.visibility().candidateCount());
        assertEquals(3, response.visibility().hiddenCandidateCount());
        assertEquals("blocked", response.visibility().hiddenReasons().getFirst().reason());
        assertEquals("user_rooftop", response.users().getFirst().userId());
        assertEquals("Rooftop Friend", response.users().getFirst().displayName());
        assertEquals("presence_service", response.users().getFirst().source());
        assertEquals("public", response.users().getFirst().visibility());
        assertEquals("visible", response.users().getFirst().visibilityReason());
        assertEquals(75.0, response.users().getFirst().shareRadiusMeters());
        assertEquals("Near the virtual wall", response.users().getFirst().statusMessage());
        assertEquals(20.42, response.users().getFirst().projection().distanceMeters());
        assertEquals(0.2, response.users().getFirst().projection().distanceRatio());
        assertEquals("near", response.users().getFirst().projection().distanceBucket());
        assertEquals(77.2, response.users().getFirst().projection().bearingDegrees());
        assertEquals(89.2, response.users().getFirst().projection().relativeBearingDegrees());
        assertEquals(0.2, response.users().getFirst().projection().relativeX());
        assertEquals(0.0, response.users().getFirst().projection().relativeY());
        assertEquals(4.4, response.users().getFirst().projection().altitudeDeltaMeters());
        assertEquals(18L, response.users().getFirst().projection().ageSeconds());
        assertEquals(102L, response.users().getFirst().projection().expiresInSeconds());
        assertEquals("fresh", response.users().getFirst().projection().freshnessState());
    }

    @Test
    void mapsLegacyPresenceNearbyResponseWithSafeDefaults() {
        HttpCameraPresenceClient client = new HttpCameraPresenceClient(
                objectMapper(),
                Optional.of("http://presence.local"),
                3);

        CameraPresenceNearbyResponse response = client.responseFromJson("""
                {
                  "viewerId": "user_current",
                  "radiusMeters": 100.0,
                  "count": 1,
                  "users": [
                    {
                      "userId": "user_rooftop",
                      "displayName": "Rooftop Friend",
                      "position": {
                        "latitude": -6.890580,
                        "longitude": 107.610970,
                        "altitudeMeters": 746.4
                      },
                      "observedAt": "2026-06-03T00:00:00Z",
                      "expiresAt": "2026-06-03T00:02:00Z"
                    }
                  ]
                }
                """, request());

        assertEquals("public", response.users().getFirst().visibility());
        assertEquals("visible", response.users().getFirst().visibilityReason());
        assertEquals(100.0, response.users().getFirst().shareRadiusMeters());
        assertEquals("", response.users().getFirst().statusMessage());
        assertEquals(1, response.totalAvailableCount());
        assertEquals(false, response.truncated());
        assertNull(response.users().getFirst().projection());
    }

    @Test
    void normalizesInvalidTimeoutToDefault() {
        HttpCameraPresenceClient client = new HttpCameraPresenceClient(
                objectMapper(),
                Optional.of("http://presence.local"),
                0);

        assertEquals(3, client.requestTimeout().toSeconds());
    }

    private CameraPresenceNearbyRequest request() {
        return new CameraPresenceNearbyRequest(
                "camera_viewer",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                88.0,
                90.0,
                90.0,
                100.0,
                25,
                Instant.parse("2026-06-03T00:00:00Z"));
    }

    private ObjectMapper objectMapper() {
        return new ObjectMapper().findAndRegisterModules();
    }
}
