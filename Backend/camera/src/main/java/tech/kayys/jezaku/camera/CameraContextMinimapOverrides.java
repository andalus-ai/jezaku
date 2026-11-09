package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;

/**
 * Rebuilds the minimap portion of a camera context for response-specific display limits.
 */
final class CameraContextMinimapOverrides {
    private CameraContextMinimapOverrides() {
    }

    static CameraContextResponse withPinLimit(CameraContextResponse context, int pinLimitPerLayer) {
        if (context == null || pinLimitPerLayer == CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER) {
            return context;
        }
        return new CameraContextResponse(
                context.viewerId(),
                context.telemetry(),
                context.totalDots(),
                context.advisoryCount(),
                context.summary(),
                context.focus(),
                context.refresh(),
                CameraMinimapViewports.from(
                        context.telemetry(),
                        context.summary(),
                        context.layers(),
                        context.totalDots(),
                        pinLimitPerLayer),
                context.advisories(),
                context.layers(),
                context.generatedAt());
    }
}
