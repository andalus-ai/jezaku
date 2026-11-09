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
import static org.junit.jupiter.api.Assertions.assertThrows;

class DefaultCameraMemoryVisibilityClientTest {
    @Test
    void localFilterRemovesOwnerBlockedAndPrivateMemoryDots() {
        DefaultCameraMemoryVisibilityClient client = client("local", Optional.empty(), true);

        CameraMemoryVisibilityResult result = client.filter(request("user_current"), new CameraMemoryOverlayResponse(
                4,
                6,
                true,
                CameraLayerSources.http("memory_service", request("user_current").now()),
                List.of(
                        dot("memory_visible", "user_rooftop", "public"),
                        dot("memory_self", "user_current", "public"),
                        dot("memory_private", "user_private", "private"),
                        dot("memory_blank_owner", "", "public"))))
                .await().indefinitely();
        CameraMemoryOverlayResponse response = result.response();

        assertEquals(1, response.count());
        assertEquals(3, response.totalAvailableCount());
        assertEquals(true, response.truncated());
        assertEquals("memory_service", response.source().effectiveSource());
        assertEquals(1, response.dots().size());
        assertEquals("memory_visible", response.dots().getFirst().id());
        assertEquals("memories", result.visibility().layer());
        assertEquals("camera_local", result.visibility().mode());
        assertEquals("memory_service", result.visibility().audienceSource());
        assertEquals("healthy", result.visibility().audienceHealth());
        assertEquals(false, result.visibility().audienceFallback());
        assertEquals(4, result.visibility().candidateCount());
        assertEquals(1, result.visibility().visibleCandidateCount());
        assertEquals(3, result.visibility().hiddenCandidateCount());
        assertEquals(List.of("self_excluded", "private", "visibility_hidden"),
                result.visibility().hiddenReasons().stream()
                        .map(CameraDtos.CameraVisibilityReasonCount::reason)
                        .toList());
    }

    @Test
    void fallsBackToLocalFilterWhenHttpSourceIsMissingBaseUrl() {
        DefaultCameraMemoryVisibilityClient client = client("http", Optional.empty(), true);

        CameraMemoryVisibilityResult result = client.filter(request("user_current"), new CameraMemoryOverlayResponse(
                2,
                2,
                false,
                CameraLayerSources.http("memory_service", request("user_current").now()),
                List.of(
                        dot("memory_visible", "user_rooftop", "public"),
                        dot("memory_self", "user_current", "public"))))
                .await().indefinitely();
        CameraMemoryOverlayResponse response = result.response();

        assertEquals(1, response.dots().size());
        assertEquals("memory_visible", response.dots().getFirst().id());
        assertEquals("memories", result.visibility().layer());
        assertEquals("fallback_local", result.visibility().mode());
        assertEquals("social", result.visibility().audienceSource());
        assertEquals("degraded", result.visibility().audienceHealth());
        assertEquals(true, result.visibility().audienceFallback());
        assertEquals(2, result.visibility().candidateCount());
        assertEquals(1, result.visibility().hiddenCandidateCount());
        assertEquals("self_excluded", result.visibility().hiddenReasons().getFirst().reason());
    }

    @Test
    void surfacesHttpConfigurationFailureWhenFallbackIsDisabled() {
        DefaultCameraMemoryVisibilityClient client = client("http", Optional.empty(), false);

        assertThrows(IllegalStateException.class, () -> client.filter(
                        request("user_current"),
                        new CameraMemoryOverlayResponse(
                                1,
                                1,
                                false,
                                CameraLayerSources.http("memory_service", request("user_current").now()),
                                List.of(dot("memory_visible", "user_rooftop", "public"))))
                .await().indefinitely());
    }

    private DefaultCameraMemoryVisibilityClient client(
            String source,
            Optional<String> socialBaseUrl,
            boolean fallbackToLocal) {
        DefaultCameraMemoryVisibilityClient client = new DefaultCameraMemoryVisibilityClient();
        client.visibilityService = new CameraVisibilityService();
        client.objectMapper = new ObjectMapper().findAndRegisterModules();
        client.source = source;
        client.socialBaseUrl = socialBaseUrl;
        client.scope = "public";
        client.targetId = "camera_memory_overlay";
        client.requestTimeoutSeconds = 3;
        client.fallbackToLocal = fallbackToLocal;
        return client;
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

    private CameraMemoryOverlayDot dot(String id, String ownerId, String visibility) {
        return new CameraMemoryOverlayDot(
                id,
                ownerId,
                "media_" + id,
                "memory_service",
                visibility,
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
