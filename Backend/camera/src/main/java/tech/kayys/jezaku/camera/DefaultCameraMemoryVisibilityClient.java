package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Selects the configured memory audience source and falls back to local visibility rules when allowed.
 */
@ApplicationScoped
class DefaultCameraMemoryVisibilityClient implements CameraMemoryVisibilityClient {
    @Inject
    CameraVisibilityService visibilityService;

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "jezaku.camera.memory-visibility.source", defaultValue = "local")
    String source;

    @ConfigProperty(name = "jezaku.camera.memory-visibility.social-base-url")
    Optional<String> socialBaseUrl;

    @ConfigProperty(name = "jezaku.camera.memory-visibility.scope", defaultValue = "public")
    String scope;

    @ConfigProperty(name = "jezaku.camera.memory-visibility.target-id", defaultValue = "camera_memory_overlay")
    String targetId;

    @ConfigProperty(name = "jezaku.camera.memory-visibility.request-timeout-seconds", defaultValue = "3")
    int requestTimeoutSeconds;

    @ConfigProperty(name = "jezaku.camera.memory-visibility.fallback-to-local", defaultValue = "true")
    boolean fallbackToLocal;

    @Override
    public Uni<CameraMemoryVisibilityResult> filter(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayResponse response) {
        return switch (normalizedSource()) {
            case "off" -> Uni.createFrom().item(CameraMemoryVisibilityReports.unreported(response));
            case "local" -> Uni.createFrom().item(localFilter(request, response));
            case "http", "social" -> httpFilter(request, response);
            default -> Uni.createFrom().failure(new IllegalStateException(
                    "Unsupported camera memory visibility source: " + source));
        };
    }

    private Uni<CameraMemoryVisibilityResult> httpFilter(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayResponse response) {
        Uni<CameraMemoryVisibilityResult> filtered = new HttpCameraMemoryVisibilityClient(
                objectMapper,
                socialBaseUrl,
                scope,
                targetId,
                requestTimeoutSeconds)
                .filter(request, response);
        if (!fallbackToLocal) {
            return filtered;
        }
        return filtered.onFailure().recoverWithItem(failure -> fallbackLocalFilter(request, response));
    }

    CameraMemoryVisibilityResult localFilter(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayResponse response) {
        List<CameraMemoryVisibilityReports.Candidate> candidates = response.dots().stream()
                .map(dot -> localCandidate(request, dot))
                .toList();
        return CameraMemoryVisibilityReports.result(
                response,
                candidates,
                "camera_local",
                CameraMemoryVisibilityReports.sourceLabel(response),
                "healthy",
                false);
    }

    private CameraMemoryVisibilityResult fallbackLocalFilter(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayResponse response) {
        List<CameraMemoryVisibilityReports.Candidate> candidates = response.dots().stream()
                .map(dot -> localCandidate(request, dot))
                .toList();
        return CameraMemoryVisibilityReports.result(
                response,
                candidates,
                "fallback_local",
                requestedAudienceSource(),
                "degraded",
                true);
    }

    private CameraMemoryVisibilityReports.Candidate localCandidate(
            CameraMemoryOverlayRequest request,
            CameraMemoryOverlayDot dot) {
        if (visibilityService.canViewMemory(request.viewerId(), dot.ownerId(), dot.visibility())) {
            return CameraMemoryVisibilityReports.visible(dot);
        }
        return CameraMemoryVisibilityReports.hidden(dot, localVisibilityReason(request, dot));
    }

    private String localVisibilityReason(CameraMemoryOverlayRequest request, CameraMemoryOverlayDot dot) {
        String viewerId = normalizeId(request.viewerId());
        String ownerId = normalizeId(dot.ownerId());
        if (ownerId.isBlank()) {
            return "visibility_hidden";
        }
        if (ownerId.equals(viewerId)) {
            return "self_excluded";
        }
        return switch (normalizeVisibility(dot.visibility())) {
            case "public" -> "blocked";
            case "friends" -> "not_friend";
            case "private" -> "private";
            default -> "visibility_hidden";
        };
    }

    private String requestedAudienceSource() {
        return "http".equals(normalizedSource()) ? "social" : normalizedSource();
    }

    private String normalizedSource() {
        return source == null || source.isBlank()
                ? "local"
                : source.trim().toLowerCase(Locale.ROOT);
    }

    private String normalizeId(String value) {
        return value == null ? "" : value.trim();
    }

    private String normalizeVisibility(String value) {
        return value == null ? "private" : value.trim().toLowerCase(Locale.ROOT);
    }
}
