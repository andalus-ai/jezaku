package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;

import java.util.Locale;
import java.util.Optional;

@ApplicationScoped
class DefaultCameraMemoryOverlayClient implements CameraMemoryOverlayClient {
    private final SeedCameraMemoryOverlayClient seedClient = new SeedCameraMemoryOverlayClient();

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "jezaku.camera.memory-overlay.source", defaultValue = "seed")
    String source;

    @ConfigProperty(name = "jezaku.camera.memory-overlay.memory-base-url")
    Optional<String> memoryBaseUrl;

    @ConfigProperty(name = "jezaku.camera.memory-overlay.request-timeout-seconds", defaultValue = "3")
    int requestTimeoutSeconds;

    @ConfigProperty(name = "jezaku.camera.memory-overlay.fallback-to-seed", defaultValue = "true")
    boolean fallbackToSeed;

    @Override
    public Uni<CameraMemoryOverlayResponse> minimap(CameraMemoryOverlayRequest request) {
        return switch (normalizedSource()) {
            case "seed" -> seedClient.minimap(request);
            case "http", "memory" -> httpMinimap(request);
            default -> Uni.createFrom().failure(new IllegalStateException(
                    "Unsupported camera memory overlay source: " + source));
        };
    }

    private Uni<CameraMemoryOverlayResponse> httpMinimap(CameraMemoryOverlayRequest request) {
        Uni<CameraMemoryOverlayResponse> response = new HttpCameraMemoryOverlayClient(
                objectMapper,
                memoryBaseUrl,
                requestTimeoutSeconds)
                .minimap(request);
        if (!fallbackToSeed) {
            return response;
        }
        return response.onFailure().recoverWithUni(failure -> seedClient.minimap(request)
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
