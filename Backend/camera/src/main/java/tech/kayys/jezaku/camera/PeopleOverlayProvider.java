package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.camera.CameraDotProjection.Projection;
import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyRequest;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyResponse;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceNearbyUser;
import tech.kayys.jezaku.camera.CameraPresenceDtos.CameraPresenceProjection;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@ApplicationScoped
public class PeopleOverlayProvider implements CameraOverlayProvider {
    @Inject
    CameraLiveSessionService liveSessions;

    @Inject
    CameraVisibilityService visibilityService;

    @Inject
    CameraPresenceClient presenceClient;

    @Override
    public String layer() {
        return "people";
    }

    @Override
    public Uni<CameraLayer> layer(CameraOverlayQuery query) {
        return presenceClient.nearby(new CameraPresenceNearbyRequest(
                query.viewerId(),
                query.origin(),
                query.headingDegrees(),
                query.compassDegrees(),
                query.orientationDegrees(),
                query.radiusMeters(),
                query.limitPerLayer(),
                query.now()))
                .map(response -> {
                    List<Candidate> candidates = presence(query, response).stream()
                            .map(seed -> candidate(seed, query))
                            .toList();
                    List<CameraDot> available = candidates.stream()
                            .filter(Candidate::visible)
                            .sorted(Comparator.comparingDouble(candidate -> candidate.dot().distanceMeters()))
                            .map(Candidate::dot)
                            .toList();
                    List<CameraDot> dots = available.stream()
                            .limit(query.limitPerLayer())
                            .toList();
                    int totalAvailable = totalAvailable(available.size(), response);
                    return new CameraLayer(layer(), "ready", "", source(response, query), dots.size(), totalAvailable,
                            truncated(totalAvailable, dots.size(), response), visibility(response, candidates),
                            CameraLayerSummaries.from(dots), dots);
                });
    }

    private CameraDtos.CameraLayerSource source(CameraPresenceNearbyResponse response, CameraOverlayQuery query) {
        return response == null || response.source() == null ? CameraLayerSources.seed(query.now()) : response.source();
    }

    private CameraDot toDot(CameraPresenceNearbyUser seed, CameraOverlayQuery query) {
        Projection computed = CameraDotProjection.from(
                query.origin(),
                seed.position(),
                query.orientationDegrees(),
                query.radiusMeters());
        CameraPresenceProjection projection = seed.projection();
        double distanceMeters = number(projection == null ? null : projection.distanceMeters(), computed.distanceMeters());
        double distanceRatio = number(projection == null ? null : projection.distanceRatio(), computed.distanceRatio());
        double bearingDegrees = number(projection == null ? null : projection.bearingDegrees(), computed.bearingDegrees());
        double relativeBearingDegrees = number(
                projection == null ? null : projection.relativeBearingDegrees(),
                computed.relativeBearingDegrees());
        double relativeX = number(projection == null ? null : projection.relativeX(), computed.relativeX());
        double relativeY = number(projection == null ? null : projection.relativeY(), computed.relativeY());
        Double altitudeDeltaMeters = nullableNumber(
                projection == null ? null : projection.altitudeDeltaMeters(),
                computed.altitudeDeltaMeters());
        long ageSeconds = longValue(
                projection == null ? null : projection.ageSeconds(),
                secondsSince(seed.observedAt(), query.now()));
        Long expiresInSeconds = nullableLong(
                projection == null ? null : projection.expiresInSeconds(),
                secondsUntil(seed.expiresAt(), query.now()));
        String distanceBucket = text(
                projection == null ? null : projection.distanceBucket(),
                CameraDotPresentation.distanceBucket(distanceRatio));
        String freshnessState = text(
                projection == null ? null : projection.freshnessState(),
                CameraDotPresentation.freshnessState(ageSeconds, expiresInSeconds));
        return new CameraDot(
                layer(),
                "presence",
                seed.userId(),
                seed.userId(),
                null,
                seed.source(),
                seed.visibility(),
                text(seed.visibilityReason(), "visible"),
                seed.expiresAt(),
                ageSeconds,
                expiresInSeconds,
                distanceBucket,
                freshnessState,
                seed.displayName(),
                seed.statusMessage(),
                null,
                seed.avatarUrl(),
                null,
                null,
                null,
                null,
                null,
                seed.position(),
                seed.headingDegrees(),
                seed.compassDegrees(),
                distanceMeters,
                distanceRatio,
                bearingDegrees,
                relativeBearingDegrees,
                relativeX,
                relativeY,
                altitudeDeltaMeters,
                seed.observedAt(),
                List.of(new CameraAction("message", "Message", "/messaging/threads?participantId=" + seed.userId())));
    }

    private List<CameraPresenceNearbyUser> presence(
            CameraOverlayQuery query,
            CameraPresenceNearbyResponse response) {
        List<CameraPresenceNearbyUser> result = new ArrayList<>(users(response));
        if (liveSessions != null) {
            liveSessions.activeSessions(query.now()).stream()
                    .map(this::toPresenceUser)
                    .forEach(result::add);
        }
        return List.copyOf(result);
    }

    private List<CameraPresenceNearbyUser> users(CameraPresenceNearbyResponse response) {
        return response == null || response.users() == null ? List.of() : response.users();
    }

    private int totalAvailable(int locallyVisibleCount, CameraPresenceNearbyResponse response) {
        return locallyVisibleCount + upstreamRemaining(response);
    }

    private int upstreamRemaining(CameraPresenceNearbyResponse response) {
        if (response == null) {
            return 0;
        }
        return Math.max(0, response.totalAvailableCount() - users(response).size());
    }

    private boolean truncated(int totalAvailable, int returnedCount, CameraPresenceNearbyResponse response) {
        return totalAvailable > returnedCount || response != null && response.truncated();
    }

    private boolean visibleToViewer(CameraPresenceNearbyUser seed, CameraOverlayQuery query) {
        return visibilityService.canViewPresence(query.viewerId(), seed.userId(), seed.visibility());
    }

    private Candidate candidate(CameraPresenceNearbyUser seed, CameraOverlayQuery query) {
        if (seed.expiresAt() == null || !seed.expiresAt().isAfter(query.now())) {
            return Candidate.hidden(seed, null, "expired");
        }
        CameraDot dot = toDot(seed, query);
        if (!visibleToViewer(seed, query)) {
            return Candidate.hidden(seed, dot, localVisibilityReason(seed, query));
        }
        if (dot.distanceMeters() > query.radiusMeters()) {
            return Candidate.hidden(seed, dot, "outside_radius");
        }
        if (dot.distanceMeters() > seed.shareRadiusMeters()) {
            return Candidate.hidden(seed, dot, "outside_share_radius");
        }
        return new Candidate(seed, dot, true, "visible");
    }

    private String localVisibilityReason(CameraPresenceNearbyUser seed, CameraOverlayQuery query) {
        if (query.viewerId() != null && query.viewerId().equals(seed.userId())) {
            return "self_excluded";
        }
        String reason = text(seed.visibilityReason(), "");
        if (!reason.isBlank() && !"visible".equals(reason) && !"seed".equals(reason) && !"live_session".equals(reason)) {
            return reason;
        }
        return "visibility_hidden";
    }

    private CameraVisibilityReport visibility(
            CameraPresenceNearbyResponse response,
            List<Candidate> candidates) {
        if (response != null && response.visibility() != null) {
            return response.visibility().withLayer(layer());
        }
        int visibleCount = (int) candidates.stream()
                .filter(Candidate::visible)
                .count();
        return new CameraVisibilityReport(
                layer(),
                "camera_local",
                sourceLabel(response),
                "healthy",
                false,
                candidates.size(),
                visibleCount,
                candidates.size() - visibleCount,
                hiddenReasonCounts(candidates));
    }

    private String sourceLabel(CameraPresenceNearbyResponse response) {
        if (response == null || response.source() == null || response.source().effectiveSource() == null) {
            return "local";
        }
        return response.source().effectiveSource();
    }

    private List<CameraVisibilityReasonCount> hiddenReasonCounts(List<Candidate> candidates) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        candidates.stream()
                .filter(candidate -> !candidate.visible())
                .forEach(candidate -> counts.merge(candidate.reason(), 1, Integer::sum));
        return counts.entrySet().stream()
                .map(entry -> new CameraVisibilityReasonCount(entry.getKey(), entry.getValue()))
                .toList();
    }

    private long secondsSince(Instant value, Instant now) {
        return Math.max(0, Duration.between(value, now).toSeconds());
    }

    private Long secondsUntil(Instant value, Instant now) {
        return value == null ? null : Math.max(0, Duration.between(now, value).toSeconds());
    }

    private double number(Double value, double fallback) {
        return value == null || !Double.isFinite(value) ? fallback : value;
    }

    private Double nullableNumber(Double value, Double fallback) {
        return value == null || !Double.isFinite(value) ? fallback : value;
    }

    private long longValue(Long value, long fallback) {
        return value == null ? fallback : Math.max(0, value);
    }

    private Long nullableLong(Long value, Long fallback) {
        return value == null ? fallback : Math.max(0, value);
    }

    private String text(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private CameraPresenceNearbyUser toPresenceUser(CameraSessionRecord session) {
        return new CameraPresenceNearbyUser(
                session.viewerId(),
                session.viewerId(),
                "live_session",
                null,
                session.position(),
                session.headingDegrees(),
                session.compassDegrees(),
                session.visibility(),
                "live_session",
                session.shareRadiusMeters(),
                session.statusMessage(),
                session.updatedAt(),
                session.expiresAt(),
                null);
    }

    private record Candidate(CameraPresenceNearbyUser seed, CameraDot dot, boolean visible, String reason) {
        static Candidate hidden(CameraPresenceNearbyUser seed, CameraDot dot, String reason) {
            return new Candidate(seed, dot, false, reason);
        }
    }
}
