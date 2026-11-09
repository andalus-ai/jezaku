package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;

interface CameraPresenceClient {
    Uni<CameraPresenceNearbyResponse> nearby(CameraPresenceNearbyRequest request);
}
