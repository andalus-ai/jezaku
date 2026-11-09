package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

/**
 * Applies viewer audience rules to memory overlay dots before they reach camera-facing surfaces.
 */
interface CameraMemoryVisibilityClient {
    Uni<CameraMemoryVisibilityResult> filter(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayResponse response);
}
