package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraContextServiceTest {
    @Test
    void degradesFailedOverlayProviderIntoUnavailableLayer() {
        CameraContextService service = new CameraContextService();

        CameraLayer layer = service.safeLayer(new FailingOverlayProvider(), query())
                .await().indefinitely();

        assertEquals("broken", layer.layer());
        assertEquals("unavailable", layer.status());
        assertEquals("Layer unavailable", layer.message());
        assertEquals(0, layer.count());
        assertEquals(0, layer.totalAvailable());
        assertFalse(layer.truncated());
        assertTrue(layer.dots().isEmpty());
    }

    @Test
    void degradesNullOverlayResponseIntoUnavailableLayer() {
        CameraContextService service = new CameraContextService();

        CameraLayer layer = service.safeLayer(new NullOverlayProvider(), query())
                .await().indefinitely();

        assertEquals("empty", layer.layer());
        assertEquals("unavailable", layer.status());
        assertEquals(0, layer.count());
        assertEquals(0, layer.totalAvailable());
        assertFalse(layer.truncated());
        assertTrue(layer.dots().isEmpty());
    }

    private CameraOverlayQuery query() {
        return new CameraOverlayQuery(
                "viewer",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                40.0,
                42.0,
                42.0,
                100.0,
                25,
                Instant.parse("2026-05-31T00:00:00Z"));
    }

    private static final class FailingOverlayProvider implements CameraOverlayProvider {
        @Override
        public String layer() {
            return "broken";
        }

        @Override
        public Uni<CameraLayer> layer(CameraOverlayQuery query) {
            return Uni.createFrom().failure(new IllegalStateException("provider failed"));
        }
    }

    private static final class NullOverlayProvider implements CameraOverlayProvider {
        @Override
        public String layer() {
            return "empty";
        }

        @Override
        public Uni<CameraLayer> layer(CameraOverlayQuery query) {
            return Uni.createFrom().item(() -> null);
        }
    }
}
