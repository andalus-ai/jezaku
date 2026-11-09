package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;

import java.time.Instant;

final class CameraLayerSources {
    private CameraLayerSources() {
    }

    static CameraLayerSource seed(Instant fetchedAt) {
        return new CameraLayerSource("seed", "seed", true, false, null, fetchedAt);
    }

    static CameraLayerSource http(String effectiveSource, Instant fetchedAt) {
        return new CameraLayerSource("http", effectiveSource, true, false, null, fetchedAt);
    }

    static CameraLayerSource fallback(String requestedSource, String effectiveSource, Throwable failure, Instant fetchedAt) {
        return new CameraLayerSource(
                requestedSource,
                effectiveSource,
                false,
                true,
                fallbackReason(failure),
                fetchedAt);
    }

    static CameraLayerSource unavailable(String effectiveSource, Instant fetchedAt) {
        return new CameraLayerSource(effectiveSource, effectiveSource, false, false, null, fetchedAt);
    }

    private static String fallbackReason(Throwable failure) {
        if (failure == null) {
            return "fallback";
        }
        String type = failure.getClass().getSimpleName();
        return type == null || type.isBlank() ? "fallback" : type;
    }
}
