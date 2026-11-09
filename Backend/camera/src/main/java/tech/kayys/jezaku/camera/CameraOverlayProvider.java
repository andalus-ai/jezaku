package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;

public interface CameraOverlayProvider {
    String layer();

    Uni<CameraLayer> layer(CameraOverlayQuery query);
}
