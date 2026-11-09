package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyUser;

import java.time.Instant;
import java.util.List;

class SeedCameraPresenceClient implements CameraPresenceClient {
    @Override
    public Uni<CameraPresenceNearbyResponse> nearby(CameraPresenceNearbyRequest request) {
        return Uni.createFrom().item(() -> {
            List<CameraPresenceNearbyUser> users = seeds(request.now());
            return new CameraPresenceNearbyResponse(
                    users.size(),
                    users.size(),
                    false,
                    CameraLayerSources.seed(request.now()),
                    users);
        });
    }

    private List<CameraPresenceNearbyUser> seeds(Instant now) {
        return List.of(
                new CameraPresenceNearbyUser(
                        "user_current",
                        "Current User",
                        "seed",
                        "https://cdn.jezaku.local/avatars/current.jpg",
                        new GeoPoint(-6.890620, 107.610790, 742.0),
                        42.0,
                        42.0,
                        "public",
                        "seed",
                        100,
                        "On the campus trail",
                        now.minusSeconds(12),
                        now.plusSeconds(120),
                        null),
                new CameraPresenceNearbyUser(
                        "user_rooftop",
                        "Rooftop Friend",
                        "seed",
                        "https://cdn.jezaku.local/avatars/rooftop.jpg",
                        new GeoPoint(-6.890580, 107.610970, 746.4),
                        87.0,
                        87.0,
                        "public",
                        "seed",
                        100,
                        "Near the virtual wall",
                        now.minusSeconds(18),
                        now.plusSeconds(120),
                        null),
                new CameraPresenceNearbyUser(
                        "user_private",
                        "Private Walker",
                        "seed",
                        "https://cdn.jezaku.local/avatars/private.jpg",
                        new GeoPoint(-6.890700, 107.610860, 741.8),
                        180.0,
                        181.0,
                        "private",
                        "seed",
                        100,
                        "Hidden",
                        now.minusSeconds(20),
                        now.plusSeconds(120),
                        null),
                new CameraPresenceNearbyUser(
                        "user_far",
                        "Far Marker",
                        "seed",
                        "https://cdn.jezaku.local/avatars/far.jpg",
                        new GeoPoint(-6.893100, 107.613300, 739.2),
                        12.0,
                        12.0,
                        "public",
                        "seed",
                        100,
                        "Outside the local radius",
                        now.minusSeconds(24),
                        now.plusSeconds(120),
                        null),
                new CameraPresenceNearbyUser(
                        "user_stale",
                        "Stale Signal",
                        "seed",
                        "https://cdn.jezaku.local/avatars/stale.jpg",
                        new GeoPoint(-6.890660, 107.610820, 741.4),
                        210.0,
                        211.0,
                        "public",
                        "seed",
                        100,
                        "Old ping",
                        now.minusSeconds(400),
                        now.minusSeconds(200),
                        null),
                new CameraPresenceNearbyUser(
                        "camera_test_east",
                        "East Camera Dot",
                        "seed",
                        "https://cdn.jezaku.local/avatars/east.jpg",
                        new GeoPoint(10.0, 20.00046, 105.5),
                        90.0,
                        90.0,
                        "public",
                        "seed",
                        100,
                        "Ahead when facing east",
                        now.minusSeconds(10),
                        now.plusSeconds(120),
                        null));
    }
}
