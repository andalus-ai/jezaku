package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayRequest;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Converts memory overlay service results into the camera memory layer shown in minimap and AR contexts.
 */
@ApplicationScoped
public class SeedMemoryOverlayProvider implements CameraOverlayProvider {
    @Inject
    CameraMemoryOverlayClient memoryOverlayClient;

    @Inject
    CameraMemoryVisibilityClient memoryVisibilityClient;

    @Override
    public String layer() {
        return "memories";
    }

    @Override
    public Uni<CameraLayer> layer(CameraOverlayQuery query) {
        CameraMemoryOverlayRequest request = new CameraMemoryOverlayRequest(
                query.viewerId(),
                query.origin(),
                query.headingDegrees(),
                query.compassDegrees(),
                query.orientationDegrees(),
                query.radiusMeters(),
                query.limitPerLayer(),
                query.now());
        return memoryOverlayClient.minimap(request)
                .chain(response -> memoryVisibilityClient.filter(request, response))
                .map(result -> toLayer(result, query));
    }

    private CameraLayer toLayer(CameraMemoryVisibilityResult result, CameraOverlayQuery query) {
        CameraMemoryOverlayResponse response = result.response();
        List<CameraDot> available = response.dots().stream()
                .map(dot -> toDot(dot, query))
                .sorted(Comparator.comparingDouble(CameraDot::distanceMeters)
                        .thenComparing(CameraDot::targetId))
                .toList();
        List<CameraDot> dots = available.stream()
                .limit(query.limitPerLayer())
                .toList();
        int totalAvailable = totalAvailable(available.size(), response);
        return new CameraLayer(
                layer(),
                "ready",
                "",
                source(response, query),
                dots.size(),
                totalAvailable,
                truncated(totalAvailable, dots.size(), response),
                visibility(result),
                CameraLayerSummaries.from(dots),
                dots);
    }

    private CameraVisibilityReport visibility(CameraMemoryVisibilityResult result) {
        return result.visibility() == null ? null : result.visibility().withLayer(layer());
    }

    private CameraDtos.CameraLayerSource source(CameraMemoryOverlayResponse response, CameraOverlayQuery query) {
        return response == null || response.source() == null ? CameraLayerSources.seed(query.now()) : response.source();
    }

    private int totalAvailable(int locallyVisibleCount, CameraMemoryOverlayResponse response) {
        return locallyVisibleCount + upstreamRemaining(response);
    }

    private int upstreamRemaining(CameraMemoryOverlayResponse response) {
        return Math.max(0, response.totalAvailableCount() - response.count());
    }

    private boolean truncated(int totalAvailable, int returnedCount, CameraMemoryOverlayResponse response) {
        return totalAvailable > returnedCount || response.truncated();
    }

    private CameraDot toDot(CameraMemoryOverlayDot memory, CameraOverlayQuery query) {
        long ageSeconds = secondsSince(memory.capturedAt(), query.now());
        return new CameraDot(
                layer(),
                "memory",
                memory.id(),
                memory.ownerId(),
                memory.mediaId(),
                memory.source(),
                memory.visibility(),
                "visible",
                null,
                ageSeconds,
                null,
                CameraDotPresentation.distanceBucket(memory.distanceRatio()),
                CameraDotPresentation.freshnessState(ageSeconds, null),
                memory.title(),
                memory.subtitle(),
                memory.mediaUrl(),
                memory.thumbnailUrl(),
                memory.mediaStatus(),
                memory.moderationStatus(),
                memory.memoryAttachable(),
                memory.publicMemoryEligible(),
                memory.anchor(),
                memory.position(),
                memory.headingDegrees(),
                memory.compassDegrees(),
                memory.distanceMeters(),
                memory.distanceRatio(),
                memory.bearingDegrees(),
                memory.relativeBearingDegrees(),
                memory.relativeX(),
                memory.relativeY(),
                memory.altitudeDeltaMeters(),
                memory.capturedAt(),
                actions(memory, memory.anchor()));
    }

    private List<CameraAction> actions(CameraMemoryOverlayDot memory, CameraAnchor anchor) {
        List<CameraAction> actions = new ArrayList<>();
        actions.add(new CameraAction("open", "Open", "/memories/" + memory.id()));
        actions.add(new CameraAction("comment", "Comment", "/engagement/targets/memory/" + memory.id()
                + "/comments"));
        if (needsAnchorRefinement(anchor)) {
            actions.add(new CameraAction("review_anchor", "Review anchor", "/memories/" + memory.id() + "/anchor"));
        }
        return List.copyOf(actions);
    }

    private boolean needsAnchorRefinement(CameraAnchor anchor) {
        if (anchor == null) {
            return false;
        }
        if (anchor.confidence() != null) {
            return !anchor.confidence().recommendedActions().isEmpty();
        }
        return !anchor.arReady();
    }

    private long secondsSince(Instant value, Instant now) {
        return Math.max(0, Duration.between(value, now).toSeconds());
    }
}
