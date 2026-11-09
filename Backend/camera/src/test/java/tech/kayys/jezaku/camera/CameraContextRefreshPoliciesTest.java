package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextRefresh;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class CameraContextRefreshPoliciesTest {
    @Test
    void blockingAdvisoryUsesFastRefresh() {
        CameraContextRefresh refresh = CameraContextRefreshPolicies.from(
                summary(0, 0, 0, 1, 1),
                List.of(layer(List.of(dot(120L)))));

        assertEquals(2, refresh.recommendedPollSeconds());
        assertEquals(2, refresh.maxAgeSeconds());
        assertEquals(120, refresh.nextExpiringDotSeconds());
        assertEquals("blocking_advisory", refresh.reason());
    }

    @Test
    void liveActivityUsesMediumRefresh() {
        CameraContextRefresh refresh = CameraContextRefreshPolicies.from(
                summary(1, 1, 0, 0, 0),
                List.of(layer(List.of(dot(120L)))));

        assertEquals(5, refresh.recommendedPollSeconds());
        assertEquals(5, refresh.maxAgeSeconds());
        assertEquals("live_activity", refresh.reason());
    }

    @Test
    void expiryCanCapRefreshBelowBasePoll() {
        CameraContextRefresh refresh = CameraContextRefreshPolicies.from(
                summary(1, 1, 0, 0, 0),
                List.of(layer(List.of(dot(3L)))));

        assertEquals(3, refresh.recommendedPollSeconds());
        assertEquals(3, refresh.maxAgeSeconds());
        assertEquals(3, refresh.nextExpiringDotSeconds());
    }

    @Test
    void staticIdleContextUsesSlowRefresh() {
        CameraContextRefresh refresh = CameraContextRefreshPolicies.from(
                summary(0, 0, 1, 0, 0),
                List.of(layer(List.of(dot(null)))));

        assertEquals(30, refresh.recommendedPollSeconds());
        assertEquals(30, refresh.maxAgeSeconds());
        assertNull(refresh.nextExpiringDotSeconds());
        assertEquals("idle", refresh.reason());
    }

    private CameraContextSummary summary(
            int liveCount,
            int freshCount,
            int staticCount,
            int criticalAdvisoryCount,
            int blockingAdvisoryCount) {
        return new CameraContextSummary(
                1,
                1,
                1,
                0,
                0,
                0,
                0,
                0,
                liveCount,
                freshCount,
                staticCount,
                0,
                0,
                0,
                criticalAdvisoryCount,
                0,
                0,
                blockingAdvisoryCount,
                criticalAdvisoryCount > 0 ? 1000 : null,
                10.0,
                10.0);
    }

    private CameraLayer layer(List<CameraDot> dots) {
        return new CameraLayer(
                "people",
                "ready",
                "",
                CameraLayerSources.seed(Instant.EPOCH),
                dots.size(),
                dots.size(),
                false,
                new CameraLayerSummary(10.0, 10.0, 0, 0, 0, 0, 0, 0, 0),
                dots);
    }

    private CameraDot dot(Long expiresInSeconds) {
        return new CameraDot(
                "people",
                "presence",
                "target",
                "owner",
                null,
                "live_session",
                "public",
                expiresInSeconds == null ? null : Instant.EPOCH.plusSeconds(expiresInSeconds),
                0,
                expiresInSeconds,
                "near",
                expiresInSeconds == null ? "static" : "fresh",
                "Target",
                "",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                new GeoPoint(0, 0, null),
                null,
                null,
                10,
                0.1,
                0,
                0,
                0,
                0,
                null,
                Instant.EPOCH,
                List.of());
    }
}
