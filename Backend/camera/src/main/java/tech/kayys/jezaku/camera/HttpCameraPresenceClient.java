package tech.kayys.jezaku.camera;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.smallrye.mutiny.Uni;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyUser;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceProjection;

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

class HttpCameraPresenceClient {
    private static final int DEFAULT_REQUEST_TIMEOUT_SECONDS = 3;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper;
    private final Optional<String> presenceBaseUrl;
    private final int requestTimeoutSeconds;

    HttpCameraPresenceClient(
            ObjectMapper objectMapper,
            Optional<String> presenceBaseUrl,
            int requestTimeoutSeconds) {
        this.objectMapper = objectMapper;
        this.presenceBaseUrl = presenceBaseUrl == null ? Optional.empty() : presenceBaseUrl;
        this.requestTimeoutSeconds = requestTimeoutSeconds;
    }

    Uni<CameraPresenceNearbyResponse> nearby(CameraPresenceNearbyRequest request) {
        HttpRequest httpRequest;
        try {
            httpRequest = HttpRequest.newBuilder(presenceNearbyUri(request))
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

    URI presenceNearbyUri(CameraPresenceNearbyRequest request) {
        String baseUrl = presenceBaseUrl
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .orElseThrow(() -> new IllegalStateException("Presence service base URL is not configured"));
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
            query.append("&viewerId=").append(urlEncode(request.viewerId()));
        }
        return URI.create(normalized + "/presence/nearby?" + query);
    }

    CameraPresenceNearbyResponse responseFromJson(String json, CameraPresenceNearbyRequest request) {
        try {
            PresenceNearbyResponse response = objectMapper.readValue(json, PresenceNearbyResponse.class);
            List<CameraPresenceNearbyUser> users = response.users() == null
                    ? List.of()
                    : response.users().stream()
                            .map(user -> toNearbyUser(user, shareRadiusMeters(response, request)))
                            .toList();
            int count = Math.max(response.count(), users.size());
            int totalAvailableCount = totalAvailableCount(response, count);
            return new CameraPresenceNearbyResponse(
                    count,
                    totalAvailableCount,
                    response.truncated() || totalAvailableCount > count,
                    CameraLayerSources.http("presence_service", request.now()),
                    visibilityReport(response.visibility()),
                    users);
        } catch (IOException exception) {
            throw new UncheckedIOException("Presence nearby response could not be parsed", exception);
        }
    }

    private CameraPresenceNearbyUser toNearbyUser(PresenceNearbyUser user, double shareRadiusMeters) {
        return new CameraPresenceNearbyUser(
                user.userId(),
                user.displayName(),
                "presence_service",
                user.avatarUrl(),
                user.position(),
                user.headingDegrees(),
                user.compassDegrees(),
                visibility(user),
                visibilityReason(user),
                shareRadiusMeters(user, shareRadiusMeters),
                statusMessage(user),
                user.observedAt(),
                user.expiresAt(),
                projection(user));
    }

    private CameraPresenceProjection projection(PresenceNearbyUser user) {
        if (!hasProjection(user)) {
            return null;
        }
        return new CameraPresenceProjection(
                user.distanceMeters(),
                user.distanceRatio(),
                user.distanceBucket(),
                user.bearingDegrees(),
                user.relativeBearingDegrees(),
                user.relativeX(),
                user.relativeY(),
                user.altitudeDeltaMeters(),
                user.ageSeconds(),
                user.expiresInSeconds(),
                user.freshnessState());
    }

    private boolean hasProjection(PresenceNearbyUser user) {
        return user.distanceMeters() != null
                || user.distanceRatio() != null
                || user.distanceBucket() != null
                || user.bearingDegrees() != null
                || user.relativeBearingDegrees() != null
                || user.relativeX() != null
                || user.relativeY() != null
                || user.altitudeDeltaMeters() != null
                || user.ageSeconds() != null
                || user.expiresInSeconds() != null
                || user.freshnessState() != null;
    }

    private String visibility(PresenceNearbyUser user) {
        return user.visibility() == null || user.visibility().isBlank()
                ? "public"
                : user.visibility().trim();
    }

    private String visibilityReason(PresenceNearbyUser user) {
        return user.visibilityReason() == null || user.visibilityReason().isBlank()
                ? "visible"
                : user.visibilityReason().trim();
    }

    private double shareRadiusMeters(PresenceNearbyUser user, double fallbackShareRadiusMeters) {
        return user.shareRadiusMeters() > 0 ? user.shareRadiusMeters() : fallbackShareRadiusMeters;
    }

    private String statusMessage(PresenceNearbyUser user) {
        return user.statusMessage() == null ? "" : user.statusMessage();
    }

    private double shareRadiusMeters(PresenceNearbyResponse response, CameraPresenceNearbyRequest request) {
        if (response.radiusMeters() > 0) {
            return response.radiusMeters();
        }
        return request.radiusMeters();
    }

    private int totalAvailableCount(PresenceNearbyResponse response, int count) {
        return response.totalAvailableCount() > 0
                ? Math.max(response.totalAvailableCount(), count)
                : count;
    }

    private CameraVisibilityReport visibilityReport(PresenceVisibilityReport visibility) {
        if (visibility == null) {
            return null;
        }
        return new CameraVisibilityReport(
                visibility.layer(),
                visibility.mode(),
                visibility.audienceSource(),
                visibility.audienceHealth(),
                visibility.audienceFallback(),
                visibility.candidateCount(),
                visibility.visibleCandidateCount(),
                visibility.hiddenCandidateCount(),
                visibility.hiddenReasons() == null
                        ? List.of()
                        : visibility.hiddenReasons().stream()
                                .map(reason -> new CameraVisibilityReasonCount(reason.reason(), reason.count()))
                                .toList());
    }

    private String successfulBody(HttpResponse<String> response) {
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new CompletionException(new IllegalStateException(
                    "Presence nearby request failed with status " + response.statusCode()));
        }
        return response.body();
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
    private record PresenceNearbyResponse(
            String viewerId,
            double radiusMeters,
            int count,
            int totalAvailableCount,
            boolean truncated,
            PresenceVisibilityReport visibility,
            List<PresenceNearbyUser> users) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record PresenceVisibilityReport(
            String layer,
            String mode,
            String audienceSource,
            String audienceHealth,
            boolean audienceFallback,
            int candidateCount,
            int visibleCandidateCount,
            int hiddenCandidateCount,
            List<PresenceVisibilityReasonCount> hiddenReasons) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record PresenceVisibilityReasonCount(String reason, int count) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private record PresenceNearbyUser(
            String userId,
            String displayName,
            String avatarUrl,
            GeoPoint position,
            Double headingDegrees,
            Double compassDegrees,
            String visibility,
            String visibilityReason,
            int shareRadiusMeters,
            String statusMessage,
            Double distanceMeters,
            Double distanceRatio,
            String distanceBucket,
            Boolean perimeter,
            Double bearingDegrees,
            Double relativeBearingDegrees,
            Double relativeX,
            Double relativeY,
            Double altitudeDeltaMeters,
            Long ageSeconds,
            Long expiresInSeconds,
            String freshnessState,
            Instant observedAt,
            Instant expiresAt) {
    }
}
