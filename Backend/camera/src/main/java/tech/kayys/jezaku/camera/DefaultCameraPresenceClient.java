package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;

import java.util.Locale;
import java.util.Optional;

@ApplicationScoped
class DefaultCameraPresenceClient implements CameraPresenceClient {
    private final SeedCameraPresenceClient seedClient = new SeedCameraPresenceClient();

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "jezaku.camera.presence.source", defaultValue = "seed")
    String source;

    @ConfigProperty(name = "jezaku.camera.presence.base-url")
    Optional<String> presenceBaseUrl;

    @ConfigProperty(name = "jezaku.camera.presence.request-timeout-seconds", defaultValue = "3")
    int requestTimeoutSeconds;

    @ConfigProperty(name = "jezaku.camera.presence.fallback-to-seed", defaultValue = "true")
    boolean fallbackToSeed;

    @Override
    public Uni<CameraPresenceNearbyResponse> nearby(CameraPresenceNearbyRequest request) {
        return switch (normalizedSource()) {
            case "seed" -> seedClient.nearby(request);
            case "http", "presence" -> httpNearby(request);
            default -> Uni.createFrom().failure(new IllegalStateException(
                    "Unsupported camera presence source: " + source));
        };
    }

    private Uni<CameraPresenceNearbyResponse> httpNearby(CameraPresenceNearbyRequest request) {
        Uni<CameraPresenceNearbyResponse> response = new HttpCameraPresenceClient(
                objectMapper,
                presenceBaseUrl,
                requestTimeoutSeconds)
                .nearby(request);
        if (!fallbackToSeed) {
            return response;
        }
        return response.onFailure().recoverWithUni(failure -> seedClient.nearby(request)
                .map(seed -> seed.withSource(CameraLayerSources.fallback(
                        normalizedSource(),
                        "seed",
                        failure,
                        request.now()))));
    }

    private String normalizedSource() {
        return source == null || source.isBlank()
                ? "seed"
                : source.trim().toLowerCase(Locale.ROOT);
    }
}
