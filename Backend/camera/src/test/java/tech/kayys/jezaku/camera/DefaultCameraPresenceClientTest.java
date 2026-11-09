package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

class DefaultCameraPresenceClientTest {
    @Test
    void fallsBackToSeedPresenceWhenHttpSourceIsMissingBaseUrl() {
        DefaultCameraPresenceClient client = new DefaultCameraPresenceClient();
        client.objectMapper = new ObjectMapper().findAndRegisterModules();
        client.source = "http";
        client.presenceBaseUrl = Optional.empty();
        client.requestTimeoutSeconds = 3;
        client.fallbackToSeed = true;

        CameraPresenceNearbyResponse response = client.nearby(request())
                .await().indefinitely();

        assertFalse(response.users().isEmpty());
        assertEquals("http", response.source().requestedSource());
        assertEquals("seed", response.source().effectiveSource());
        assertEquals(false, response.source().healthy());
        assertEquals(true, response.source().fallback());
        assertEquals("IllegalStateException", response.source().fallbackReason());
    }

    @Test
    void surfacesHttpConfigurationFailureWhenFallbackIsDisabled() {
        DefaultCameraPresenceClient client = new DefaultCameraPresenceClient();
        client.objectMapper = new ObjectMapper().findAndRegisterModules();
        client.source = "http";
        client.presenceBaseUrl = Optional.empty();
        client.requestTimeoutSeconds = 3;
        client.fallbackToSeed = false;

        assertThrows(IllegalStateException.class, () -> client.nearby(request())
                .await().indefinitely());
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
}
