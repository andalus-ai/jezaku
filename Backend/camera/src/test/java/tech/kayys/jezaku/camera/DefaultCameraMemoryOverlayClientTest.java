package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DefaultCameraMemoryOverlayClientTest {
    @Test
    void fallsBackToSeedOverlayWhenHttpSourceIsMissingBaseUrl() {
        DefaultCameraMemoryOverlayClient client = new DefaultCameraMemoryOverlayClient();
        client.objectMapper = new ObjectMapper().findAndRegisterModules();
        client.source = "http";
        client.memoryBaseUrl = Optional.empty();
        client.requestTimeoutSeconds = 3;
        client.fallbackToSeed = true;

        CameraMemoryOverlayResponse response = client.minimap(request())
                .await().indefinitely();

        assertFalse(response.dots().isEmpty());
        assertEquals("http", response.source().requestedSource());
        assertEquals("seed", response.source().effectiveSource());
        assertEquals(false, response.source().healthy());
        assertEquals(true, response.source().fallback());
        assertEquals("IllegalStateException", response.source().fallbackReason());
    }

    @Test
    void surfacesHttpConfigurationFailureWhenFallbackIsDisabled() {
        DefaultCameraMemoryOverlayClient client = new DefaultCameraMemoryOverlayClient();
        client.objectMapper = new ObjectMapper().findAndRegisterModules();
        client.source = "http";
        client.memoryBaseUrl = Optional.empty();
        client.requestTimeoutSeconds = 3;
        client.fallbackToSeed = false;

        assertThrows(IllegalStateException.class, () -> client.minimap(request())
                .await().indefinitely());
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
