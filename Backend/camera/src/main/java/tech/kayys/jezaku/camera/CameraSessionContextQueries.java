package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;

@ApplicationScoped
public class CameraSessionContextQueries {
    @Inject
    CameraContextService contexts;

    Uni<CameraContextResponse> forSession(
            CameraSessionRecord session,
            Double radiusMeters,
            Integer limitPerLayer,
            String layers) {
        return contexts.context(
                session.viewerId(),
                session.position().latitude(),
                session.position().longitude(),
                session.position().altitudeMeters(),
                session.headingDegrees(),
                session.compassDegrees(),
                session.speedMetersPerSecond(),
                null,
                null,
                null,
                null,
                null,
                radiusMeters == null ? session.radiusMeters() : radiusMeters,
                limitPerLayer,
                layers);
    }
}
