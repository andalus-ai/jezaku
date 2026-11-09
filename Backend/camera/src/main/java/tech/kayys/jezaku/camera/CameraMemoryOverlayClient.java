package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;

interface CameraMemoryOverlayClient {
    Uni<CameraMemoryOverlayResponse> minimap(CameraMemoryOverlayRequest request);
}
