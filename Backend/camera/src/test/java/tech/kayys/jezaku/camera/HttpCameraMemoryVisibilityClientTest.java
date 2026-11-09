package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HttpCameraMemoryVisibilityClientTest {
    @Test
    void buildsSocialAudienceAccessUri() {
        HttpCameraMemoryVisibilityClient client = client(Optional.of("http://social.local/"));

        assertEquals("http://social.local/social/audience/access", client.socialAudienceAccessUri().toString());
    }

    @Test
    void buildsSocialAudienceAccessPayloadWithDistinctOwners() {
        HttpCameraMemoryVisibilityClient client = client(Optional.of("http://social.local"));

        String json = client.json(request("user_current"), new CameraMemoryOverlayResponse(
                3,
                5,
                true,
                CameraLayerSources.http("memory_service", request("user_current").now()),
                List.of(
                        dot("memory_one", "user_rooftop"),
                        dot("memory_two", "user_lens"),
                        dot("memory_three", "user_lens"))));

        assertTrue(json.contains("\"viewerId\":\"user_current\""));
        assertTrue(json.contains("\"scope\":\"public\""));
        assertTrue(json.contains("\"targetId\":\"camera_memory_overlay\""));
        assertTrue(json.contains("\"ownerIds\":[\"user_rooftop\",\"user_lens\"]"));
    }

    @Test
    void filtersOverlayDotsFromSocialAudienceResponse() {
        HttpCameraMemoryVisibilityClient client = client(Optional.of("http://social.local"));
        CameraMemoryOverlayResponse response = new CameraMemoryOverlayResponse(
                3,
                5,
                true,
                CameraLayerSources.http("memory_service", request("user_current").now()),
                List.of(
                        dot("memory_allowed", "user_rooftop"),
                        dot("memory_denied", "user_blocked"),
                        dot("memory_allowed_second", "user_lens")));

        CameraMemoryVisibilityResult result = client.filterFromJson(response, """
                {
                  "viewerId": "user_current",
                  "scope": "public",
                  "targetId": "camera_memory_overlay",
                  "audienceSource": "social",
                  "audienceHealth": "healthy",
                  "count": 3,
                  "allowedOwnerIds": ["user_rooftop", "user_lens"],
                  "deniedOwnerIds": ["user_blocked"],
                  "decisions": [
                    { "ownerId": "user_rooftop", "allowed": true, "reason": "friend" },
                    { "ownerId": "user_lens", "allowed": true, "reason": "public" },
                    { "ownerId": "user_blocked", "allowed": false, "reason": "blocked" }
                  ]
                }
                """);
        CameraMemoryOverlayResponse filtered = result.response();

        assertEquals(2, filtered.count());
        assertEquals(4, filtered.totalAvailableCount());
        assertEquals(true, filtered.truncated());
        assertEquals("memory_service", filtered.source().effectiveSource());
        assertEquals(2, filtered.dots().size());
        assertEquals("memory_allowed", filtered.dots().getFirst().id());
        assertEquals("memory_allowed_second", filtered.dots().get(1).id());
        assertEquals("memories", result.visibility().layer());
        assertEquals("social_audience", result.visibility().mode());
        assertEquals("social", result.visibility().audienceSource());
        assertEquals("healthy", result.visibility().audienceHealth());
        assertEquals(false, result.visibility().audienceFallback());
        assertEquals(3, result.visibility().candidateCount());
        assertEquals(2, result.visibility().visibleCandidateCount());
        assertEquals(1, result.visibility().hiddenCandidateCount());
        assertEquals("blocked", result.visibility().hiddenReasons().getFirst().reason());
    }

    @Test
    void reportsFallbackAudienceHealthFromSocialAudienceResponse() {
        HttpCameraMemoryVisibilityClient client = client(Optional.of("http://social.local"));
        CameraMemoryOverlayResponse response = new CameraMemoryOverlayResponse(
                1,
                1,
                false,
                CameraLayerSources.http("memory_service", request("user_current").now()),
                List.of(dot("memory_denied", "user_blocked")));

        CameraMemoryVisibilityResult result = client.filterFromJson(response, """
                {
                  "audienceFallback": true,
                  "allowedOwnerIds": [],
                  "deniedOwnerIds": ["user_blocked"]
                }
                """);

        assertEquals("memories", result.visibility().layer());
        assertEquals("degraded", result.visibility().audienceHealth());
        assertEquals(true, result.visibility().audienceFallback());
        assertEquals("denied", result.visibility().hiddenReasons().getFirst().reason());
    }

    @Test
    void normalizesInvalidTimeoutToDefault() {
        HttpCameraMemoryVisibilityClient client = new HttpCameraMemoryVisibilityClient(
                new ObjectMapper().findAndRegisterModules(),
                Optional.of("http://social.local"),
                "public",
                "camera_memory_overlay",
                0);

        assertEquals(3, client.requestTimeout().toSeconds());
    }

    private HttpCameraMemoryVisibilityClient client(Optional<String> socialBaseUrl) {
        return new HttpCameraMemoryVisibilityClient(
                new ObjectMapper().findAndRegisterModules(),
                socialBaseUrl,
                "public",
                "camera_memory_overlay",
                3);
    }

    private CameraMemoryOverlayRequest request(String viewerId) {
        return new CameraMemoryOverlayRequest(
                viewerId,
                new GeoPoint(-6.890620, 107.610790, 742.0),
                88.0,
                90.0,
                90.0,
                100.0,
                25,
                Instant.parse("2026-06-03T00:00:00Z"));
    }

    private CameraMemoryOverlayDot dot(String id, String ownerId) {
        return new CameraMemoryOverlayDot(
                id,
                ownerId,
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
                null,
                new GeoPoint(-6.890700, 107.610850, 742.0),
                42.0,
                42.0,
                12.0,
                0.12,
                45.0,
                3.0,
                0.05,
                -0.11,
                1.5,
                Instant.parse("2026-06-03T00:00:00Z"));
    }
}
