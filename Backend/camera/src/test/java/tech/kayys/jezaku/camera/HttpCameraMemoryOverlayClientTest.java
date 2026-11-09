package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;

import java.net.URI;
import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HttpCameraMemoryOverlayClientTest {
    @Test
    void buildsMemoryMinimapUriFromCameraOverlayRequest() {
        HttpCameraMemoryOverlayClient client = new HttpCameraMemoryOverlayClient(
                objectMapper(),
                Optional.of("http://memory.local/"),
                3);

        URI uri = client.memoryMinimapUri(new CameraMemoryOverlayRequest(
                "user current",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                88.0,
                90.0,
                90.0,
                100.0,
                25,
                Instant.parse("2026-06-03T00:00:00Z")));

        assertEquals(
                "http://memory.local/memories/minimap?lat=-6.89062&lng=107.61079"
                        + "&radiusMeters=100.0&limit=25&headingDegrees=88.0&compassDegrees=90.0"
                        + "&altitudeMeters=742.0&excludeOwnerId=user+current",
                uri.toString());
    }

    @Test
    void mapsMemoryMinimapResponseIntoCameraOverlayDots() {
        HttpCameraMemoryOverlayClient client = new HttpCameraMemoryOverlayClient(
                objectMapper(),
                Optional.of("http://memory.local"),
                3);

        CameraMemoryOverlayResponse response = client.responseFromJson("""
                {
                  "center": {"latitude": -6.890620, "longitude": 107.610790, "altitudeMeters": 742.0},
                  "count": 1,
                  "totalAvailableCount": 3,
                  "truncated": true,
                  "summary": {"dotCount": 1},
                  "clusters": [],
                  "dots": [
                    {
                      "id": "memory_service_rooftop",
                      "ownerId": "user_rooftop",
                      "mediaId": "media_rooftop",
                      "mediaStatus": "active",
                      "moderationStatus": "approved",
                      "memoryAttachable": true,
                      "publicMemoryEligible": true,
                      "mediaUrl": "https://cdn.jezaku.local/media/rooftop.webp",
                      "thumbnailUrl": "https://cdn.jezaku.local/memories/rooftop-thumb.jpg",
                      "caption": "Skyline marker",
                      "position": {
                        "latitude": -6.890580,
                        "longitude": 107.610970,
                        "altitudeMeters": 746.4
                      },
                      "headingDegrees": 87.0,
                      "compassDegrees": 87.0,
                      "anchor": {
                        "type": "geo",
                        "quality": "high",
                        "arReady": true,
                        "revision": 2,
                        "source": "refinement",
                        "updatedAt": "2026-06-03T00:00:00Z",
                        "position": {
                          "latitude": -6.890580,
                          "longitude": 107.610970,
                          "altitudeMeters": 746.4
                        },
                        "headingDegrees": 87.0,
                        "compassDegrees": 87.0,
                        "pitchDegrees": -8.5,
                        "rollDegrees": 0.5,
                        "gpsAccuracyMeters": 4.2,
                        "confidence": {
                          "score": 88,
                          "level": "high",
                          "reasons": ["gps_accuracy_high"],
                          "recommendedActions": []
                        }
                      },
                      "tags": ["camera"],
                      "placeId": "place_rooftop_lane",
                      "distanceMeters": 20.42,
                      "distanceRatio": 0.2,
                      "perimeter": false,
                      "bearingDegrees": 77.2,
                      "relativeBearingDegrees": 89.2,
                      "relativeX": 0.2,
                      "relativeY": 0.0,
                      "altitudeDeltaMeters": 4.4,
                      "capturedAt": "2026-06-03T00:00:00Z"
                    }
                  ]
                }
                """, request());

        assertEquals(1, response.count());
        assertEquals(3, response.totalAvailableCount());
        assertEquals(true, response.truncated());
        assertEquals("http", response.source().requestedSource());
        assertEquals("memory_service", response.source().effectiveSource());
        assertEquals(true, response.source().healthy());
        assertEquals(false, response.source().fallback());
        assertEquals("memory_service_rooftop", response.dots().getFirst().id());
        assertEquals("memory_service", response.dots().getFirst().source());
        assertEquals("public", response.dots().getFirst().visibility());
        assertEquals("Skyline marker", response.dots().getFirst().title());
        assertEquals("place_rooftop_lane", response.dots().getFirst().subtitle());
        assertEquals("high", response.dots().getFirst().anchor().confidence().level());
        assertTrue(response.dots().getFirst().anchor().arReady());
    }

    @Test
    void normalizesInvalidTimeoutToDefault() {
        HttpCameraMemoryOverlayClient client = new HttpCameraMemoryOverlayClient(
                objectMapper(),
                Optional.of("http://memory.local"),
                0);

        assertEquals(3, client.requestTimeout().toSeconds());
    }

    private ObjectMapper objectMapper() {
        return new ObjectMapper().findAndRegisterModules();
    }

    private CameraMemoryOverlayRequest request() {
        return new CameraMemoryOverlayRequest(
                "camera_viewer",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                88.0,
                90.0,
                90.0,
                100.0,
                25,
                Instant.parse("2026-06-03T00:00:00Z"));
    }
}
