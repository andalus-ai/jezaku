package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchorConfidence;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletionException;

class HttpCameraMemoryOverlayClient {
    private static final int DEFAULT_REQUEST_TIMEOUT_SECONDS = 3;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper;
    private final Optional<String> memoryBaseUrl;
    private final int requestTimeoutSeconds;

    HttpCameraMemoryOverlayClient(
            ObjectMapper objectMapper,
            Optional<String> memoryBaseUrl,
            int requestTimeoutSeconds) {
        this.objectMapper = objectMapper;
        this.memoryBaseUrl = memoryBaseUrl == null ? Optional.empty() : memoryBaseUrl;
        this.requestTimeoutSeconds = requestTimeoutSeconds;
    }

    Uni<CameraMemoryOverlayResponse> minimap(CameraMemoryOverlayRequest request) {
        HttpRequest httpRequest;
        try {
            httpRequest = HttpRequest.newBuilder(memoryMinimapUri(request))
                    .timeout(requestTimeout())
                    .GET()
                    .build();
        } catch (RuntimeException exception) {
            return Uni.createFrom().failure(exception);
        }
        return Uni.createFrom().completionStage(() -> httpClient
                .sendAsync(httpRequest, HttpResponse.BodyHandlers.ofString())
                .thenApply(this::successfulBody)
                .thenApply(json -> responseFromJson(json, request)));
    }

    URI memoryMinimapUri(CameraMemoryOverlayRequest request) {
        String baseUrl = memoryBaseUrl
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("Memory service base URL is not configured"));
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        StringBuilder query = new StringBuilder()
                .append("lat=").append(request.origin().latitude())
                .append("&lng=").append(request.origin().longitude())
                .append("&radiusMeters=").append(request.radiusMeters())
                .append("&limit=").append(request.limit());
        if (request.headingDegrees() != null) {
            query.append("&headingDegrees=").append(request.headingDegrees());
        }
        if (request.compassDegrees() != null) {
            query.append("&compassDegrees=").append(request.compassDegrees());
        }
        if (request.origin().altitudeMeters() != null) {
            query.append("&altitudeMeters=").append(request.origin().altitudeMeters());
        }
        if (request.viewerId() != null && !request.viewerId().isBlank()) {
            query.append("&excludeOwnerId=").append(urlEncode(request.viewerId()));
        }
        return URI.create(normalized + "/memories/minimap?" + query);
    }

    CameraMemoryOverlayResponse responseFromJson(String json, CameraMemoryOverlayRequest request) {
        try {
            MemoryMinimapResponse response = objectMapper.readValue(json, MemoryMinimapResponse.class);
            List<CameraMemoryOverlayDot> dots = response.dots() == null
                    ? List.of()
                    : response.dots().stream()
                            .map(this::toOverlayDot)
                            .toList();
            int count = Math.max(response.count(), dots.size());
            int totalAvailableCount = response.totalAvailableCount() > 0
                    ? Math.max(response.totalAvailableCount(), count)
                    : count;
            return new CameraMemoryOverlayResponse(
                    count,
                    totalAvailableCount,
                    response.truncated() || totalAvailableCount > count,
                    CameraLayerSources.http("memory_service", request.now()),
                    dots);
        } catch (IOException exception) {
            throw new UncheckedIOException("Memory minimap response could not be parsed", exception);
        }
    }

    private String successfulBody(HttpResponse<String> response) {
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new CompletionException(new IllegalStateException(
                    "Memory minimap request failed with status " + response.statusCode()));
        }
        return response.body();
    }

    private CameraMemoryOverlayDot toOverlayDot(MemoryMinimapDot dot) {
        CameraAnchor anchor = toAnchor(dot.anchor());
        return new CameraMemoryOverlayDot(
                dot.id(),
                dot.ownerId(),
                dot.mediaId(),
                "memory_service",
                "public",
                dot.mediaStatus(),
                dot.moderationStatus(),
                dot.memoryAttachable(),
                dot.publicMemoryEligible(),
                dot.caption(),
                dot.placeId(),
                dot.mediaUrl(),
                dot.thumbnailUrl(),
                anchor,
                dot.position(),
                dot.headingDegrees(),
                dot.compassDegrees(),
                dot.distanceMeters(),
                dot.distanceRatio(),
                dot.bearingDegrees(),
                dot.relativeBearingDegrees(),
                dot.relativeX(),
                dot.relativeY(),
                dot.altitudeDeltaMeters(),
                dot.capturedAt());
    }

    private CameraAnchor toAnchor(MemoryAnchor anchor) {
        if (anchor == null) {
            return null;
        }
        return new CameraAnchor(
                anchor.type(),
                anchor.quality(),
                anchor.arReady(),
                anchor.position(),
                anchor.headingDegrees(),
                anchor.compassDegrees(),
                anchor.pitchDegrees(),
                anchor.rollDegrees(),
                anchor.gpsAccuracyMeters(),
                toConfidence(anchor.confidence()));
    }

    private CameraAnchorConfidence toConfidence(MemoryAnchorConfidence confidence) {
        if (confidence == null) {
            return null;
        }
        return new CameraAnchorConfidence(
                confidence.score(),
                confidence.level(),
                confidence.reasons() == null ? List.of() : confidence.reasons(),
                confidence.recommendedActions() == null ? List.of() : confidence.recommendedActions());
    }

    Duration requestTimeout() {
        int normalizedSeconds = requestTimeoutSeconds <= 0
                ? DEFAULT_REQUEST_TIMEOUT_SECONDS
                : requestTimeoutSeconds;
        return Duration.ofSeconds(normalizedSeconds);
    }

    private String urlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record MemoryMinimapResponse(
            int count,
            int totalAvailableCount,
            boolean truncated,
            List<MemoryMinimapDot> dots) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record MemoryMinimapDot(
            String id,
            String ownerId,
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            String mediaUrl,
            String thumbnailUrl,
            String caption,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            MemoryAnchor anchor,
            List<String> tags,
            String placeId,
            double distanceMeters,
            double distanceRatio,
            boolean perimeter,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            Instant capturedAt) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record MemoryAnchor(
            String type,
            String quality,
            boolean arReady,
            int revision,
            String source,
            Instant updatedAt,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters,
            MemoryAnchorConfidence confidence) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record MemoryAnchorConfidence(
            int score,
            String level,
            List<String> reasons,
            List<String> recommendedActions) {
    }
}
