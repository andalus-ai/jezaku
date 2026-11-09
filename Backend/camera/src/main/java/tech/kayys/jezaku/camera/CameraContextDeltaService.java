package tech.kayys.jezaku.camera;

import jakarta.enterprise.context.ApplicationScoped;
import tech.kayys.jezaku.camera.CameraDtos.CameraAdvisory;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaEvent;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;

@ApplicationScoped
class CameraContextDeltaService {
    private final ConcurrentMap<String, ContextSnapshot> snapshots = new ConcurrentHashMap<>();

    CameraContextDeltaResponse delta(String sessionId, CameraContextResponse context, Instant now) {
        return delta(sessionId, context, now, CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT);
    }

    CameraContextDeltaResponse delta(
            String sessionId,
            CameraContextResponse context,
            Instant now,
            Integer limit) {
        int deltaLimit = normalizeBoundedInt(
                limit,
                CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT,
                CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT,
                CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT,
                "contextDeltaLimit");
        Map<String, ContextSignal> current = snapshot(context);
        String baselineKey = baselineKey(context);
        ContextSnapshot previousSnapshot = snapshots.put(sessionId, new ContextSnapshot(baselineKey, current));
        String resetReason = resetReason(previousSnapshot, baselineKey);
        boolean baselineReset = resetReason != null;
        Map<String, ContextSignal> previous = baselineReset ? Map.of() : previousSnapshot.signals();

        List<CameraContextDeltaEvent> available = sortedEvents(current, previous, now);
        List<CameraContextDeltaEvent> returned = available.stream()
                .limit(deltaLimit)
                .toList();
        return new CameraContextDeltaResponse(
                sessionId,
                baselineKey,
                baselineReset,
                resetReason == null ? "" : resetReason,
                returned.size(),
                available.size(),
                available.size() > returned.size(),
                (int) returned.stream().filter(event -> "dot.entered".equals(event.type())).count(),
                (int) returned.stream().filter(event -> "dot.left".equals(event.type())).count(),
                (int) returned.stream().filter(event -> "dot.updated".equals(event.type())).count(),
                (int) returned.stream().filter(event -> event.type().startsWith("advisory.")).count(),
                (int) returned.stream().filter(event -> event.type().startsWith("layer.")).count(),
                returned,
                now);
    }

    void clear(String sessionId) {
        snapshots.remove(sessionId);
    }

    private List<CameraContextDeltaEvent> sortedEvents(
            Map<String, ContextSignal> current,
            Map<String, ContextSignal> previous,
            Instant now) {
        List<CameraContextDeltaEvent> events = new ArrayList<>();
        for (ContextSignal signal : current.values()) {
            ContextSignal previousSignal = previous.get(signal.key());
            if (previousSignal == null) {
                if (!"layer".equals(signal.kind())) {
                    events.add(event(enteredType(signal), signal, now));
                }
                continue;
            }
            List<String> changeReasons = changeReasons(signal, previousSignal);
            if (!changeReasons.isEmpty()) {
                events.add(event(updatedType(signal, changeReasons), signal, previousSignal, changeReasons, now));
            }
        }
        for (ContextSignal signal : previous.values()) {
            if (!current.containsKey(signal.key()) && !"layer".equals(signal.kind())) {
                events.add(event(leftType(signal), signal, now));
            }
        }
        return events.stream()
                .sorted(Comparator.comparingInt(this::eventPriority)
                        .thenComparingDouble(this::distanceSortValue)
                        .thenComparing(CameraContextDeltaEvent::layer)
                        .thenComparing(CameraContextDeltaEvent::targetId))
                .toList();
    }

    private String resetReason(ContextSnapshot previousSnapshot, String baselineKey) {
        if (previousSnapshot == null) {
            return "first_sync";
        }
        if (!previousSnapshot.baselineKey().equals(baselineKey)) {
            return "view_changed";
        }
        return null;
    }

    private String baselineKey(CameraContextResponse context) {
        String layers = context.layers().stream()
                .map(layer -> layer.layer())
                .sorted()
                .collect(Collectors.joining(","));
        return "radius=" + context.telemetry().radiusMeters() + "|layers=" + layers;
    }

    private Map<String, ContextSignal> snapshot(CameraContextResponse context) {
        Map<String, ContextSignal> signals = new LinkedHashMap<>();
        for (var layer : context.layers()) {
            ContextSignal signal = layerSignal(layer);
            signals.put(signal.key(), signal);
            for (CameraDot dot : layer.dots()) {
                ContextSignal dotSignal = dotSignal(dot);
                signals.put(dotSignal.key(), dotSignal);
            }
        }
        for (CameraAdvisory advisory : context.advisories()) {
            ContextSignal signal = advisorySignal(advisory);
            signals.put(signal.key(), signal);
        }
        return Map.copyOf(signals);
    }

    private ContextSignal dotSignal(CameraDot dot) {
        String key = "dot|" + dot.layer() + "|" + dot.targetType() + "|" + dot.targetId();
        return new ContextSignal(
                key,
                "dot",
                dot.layer(),
                null,
                dot.targetType(),
                dot.targetId(),
                dot.title(),
                "",
                dotDisplayMode(dot),
                null,
                null,
                null,
                null,
                null,
                false,
                dot.visibility(),
                dot.visibilityReason(),
                null,
                dot.distanceBucket(),
                dot.freshnessState(),
                anchorConfidenceLevel(dot),
                dot.anchor() == null ? null : dot.anchor().arReady(),
                dot.publicMemoryEligible(),
                dot.mediaStatus(),
                dot.moderationStatus(),
                dot.distanceMeters());
    }

    private ContextSignal layerSignal(CameraLayer layer) {
        CameraLayerSource source = layer.source();
        String key = "layer|" + layer.layer();
        return new ContextSignal(
                key,
                "layer",
                layer.layer(),
                layer.status(),
                "layer",
                layer.layer(),
                layerLabel(layer.layer()),
                layerSeverity(layer),
                "layer_health",
                source == null ? null : source.requestedSource(),
                source == null ? null : source.effectiveSource(),
                source == null ? null : source.healthy(),
                source == null ? null : source.fallback(),
                source == null ? null : source.fallbackReason(),
                layer.truncated(),
                null,
                null,
                layer.visibility(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null);
    }

    private ContextSignal advisorySignal(CameraAdvisory advisory) {
        String key = "advisory|" + advisory.severity() + "|" + advisory.layer() + "|"
                + advisory.targetType() + "|" + advisory.targetId() + "|" + advisory.actionType();
        return new ContextSignal(
                key,
                "advisory",
                advisory.layer(),
                null,
                advisory.targetType(),
                advisory.targetId(),
                advisory.title(),
                advisory.severity(),
                advisory.displayMode(),
                null,
                null,
                null,
                null,
                null,
                false,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                advisory.distanceMeters());
    }

    private CameraContextDeltaEvent event(String type, ContextSignal signal, Instant now) {
        return event(type, signal, null, List.of(), now);
    }

    private CameraContextDeltaEvent event(
            String type,
            ContextSignal signal,
            ContextSignal previousSignal,
            List<String> changeReasons,
            Instant now) {
        return new CameraContextDeltaEvent(
                type + ":" + signal.key(),
                type,
                signal.layer(),
                signal.targetType(),
                signal.targetId(),
                signal.title(),
                signal.severity(),
                signal.displayMode(),
                signal.visibility(),
                signal.visibilityReason(),
                signal.visibilityReport(),
                changeReasons,
                signal.distanceBucket(),
                signal.freshnessState(),
                signal.anchorConfidenceLevel(),
                signal.anchorArReady(),
                signal.distanceMeters(),
                previousSignal == null ? null : previousSignal.distanceMeters(),
                now);
    }

    private String enteredType(ContextSignal signal) {
        return "advisory".equals(signal.kind()) ? "advisory.active" : "dot.entered";
    }

    private String updatedType(ContextSignal signal, List<String> changeReasons) {
        if ("layer".equals(signal.kind())
                && changeReasons.size() == 1
                && changeReasons.contains("visibility_report_changed")) {
            return "layer.visibility.changed";
        }
        return "layer".equals(signal.kind()) ? "layer.health.changed" : "dot.updated";
    }

    private String leftType(ContextSignal signal) {
        return "advisory".equals(signal.kind()) ? "advisory.cleared" : "dot.left";
    }

    private String dotDisplayMode(CameraDot dot) {
        return switch (dot.targetType()) {
            case "memory" -> dot.anchor() != null
                    && dot.anchor().arReady()
                    && Boolean.TRUE.equals(dot.publicMemoryEligible()) ? "ar_photo" : "photo_hint";
            case "safety_zone" -> "safety_zone";
            case "presence" -> "marker";
            default -> "marker";
        };
    }

    private String anchorConfidenceLevel(CameraDot dot) {
        if (dot.anchor() == null) {
            return null;
        }
        if (dot.anchor().confidence() != null) {
            return dot.anchor().confidence().level();
        }
        return dot.anchor().quality();
    }

    private List<String> changeReasons(ContextSignal current, ContextSignal previous) {
        if ("layer".equals(current.kind()) && "layer".equals(previous.kind())) {
            return layerChangeReasons(current, previous);
        }
        if ("dot".equals(current.kind()) && "dot".equals(previous.kind())) {
            return dotChangeReasons(current, previous);
        }
        return List.of();
    }

    private List<String> dotChangeReasons(ContextSignal current, ContextSignal previous) {
        if (!"dot".equals(current.kind()) || !"dot".equals(previous.kind())) {
            return List.of();
        }
        List<String> reasons = new ArrayList<>();
        if (!Objects.equals(current.distanceBucket(), previous.distanceBucket())) {
            reasons.add("distance_bucket_changed");
        }
        if (!Objects.equals(current.freshnessState(), previous.freshnessState())) {
            reasons.add("freshness_changed");
        }
        if (!Objects.equals(current.displayMode(), previous.displayMode())) {
            reasons.add("display_mode_changed");
        }
        if (!Objects.equals(current.visibility(), previous.visibility())) {
            reasons.add("visibility_changed");
        }
        if (!Objects.equals(current.visibilityReason(), previous.visibilityReason())) {
            reasons.add("visibility_reason_changed");
        }
        if (!Objects.equals(current.anchorConfidenceLevel(), previous.anchorConfidenceLevel())) {
            reasons.add("anchor_confidence_changed");
        }
        if (!Objects.equals(current.anchorArReady(), previous.anchorArReady())) {
            reasons.add("anchor_readiness_changed");
        }
        if (!Objects.equals(current.publicMemoryEligible(), previous.publicMemoryEligible())) {
            reasons.add("public_memory_eligibility_changed");
        }
        if (!Objects.equals(current.mediaStatus(), previous.mediaStatus())
                || !Objects.equals(current.moderationStatus(), previous.moderationStatus())) {
            reasons.add("media_state_changed");
        }
        return reasons;
    }

    private List<String> layerChangeReasons(ContextSignal current, ContextSignal previous) {
        List<String> reasons = new ArrayList<>();
        if (!Objects.equals(current.layerStatus(), previous.layerStatus())) {
            reasons.add("layer_status_changed");
        }
        if (!Objects.equals(current.requestedSource(), previous.requestedSource())) {
            reasons.add("source_requested_changed");
        }
        if (!Objects.equals(current.effectiveSource(), previous.effectiveSource())) {
            reasons.add("source_effective_changed");
        }
        if (!Objects.equals(current.sourceHealthy(), previous.sourceHealthy())) {
            reasons.add("source_health_changed");
        }
        if (!Objects.equals(current.sourceFallback(), previous.sourceFallback())) {
            reasons.add("source_fallback_changed");
        }
        if (!Objects.equals(current.fallbackReason(), previous.fallbackReason())) {
            reasons.add("source_fallback_reason_changed");
        }
        if (!Objects.equals(current.truncated(), previous.truncated())) {
            reasons.add("layer_truncation_changed");
        }
        if (!Objects.equals(current.visibilityReport(), previous.visibilityReport())) {
            reasons.add("visibility_report_changed");
        }
        return reasons;
    }

    private int eventPriority(CameraContextDeltaEvent event) {
        return switch (event.type()) {
            case "advisory.active" -> 0;
            case "layer.health.changed", "layer.visibility.changed" -> 1;
            case "dot.entered" -> 2;
            case "dot.updated" -> 3;
            case "advisory.cleared" -> 4;
            case "dot.left" -> 5;
            default -> 4;
        };
    }

    private String layerLabel(String layer) {
        return switch (layer) {
            case "safety" -> "Safety layer";
            case "people" -> "People layer";
            case "memories" -> "Memories layer";
            default -> layer + " layer";
        };
    }

    private String layerSeverity(CameraLayer layer) {
        CameraLayerSource source = layer.source();
        if (!"ready".equals(layer.status()) || (source != null && !source.healthy() && !source.fallback())) {
            return "critical";
        }
        if (layer.truncated() || (source != null && source.fallback())) {
            return "warning";
        }
        return "info";
    }

    private double distanceSortValue(CameraContextDeltaEvent event) {
        return event.distanceMeters() == null ? Double.MAX_VALUE : event.distanceMeters();
    }

    private record ContextSignal(
            String key,
            String kind,
            String layer,
            String layerStatus,
            String targetType,
            String targetId,
            String title,
            String severity,
            String displayMode,
            String requestedSource,
            String effectiveSource,
            Boolean sourceHealthy,
            Boolean sourceFallback,
            String fallbackReason,
            Boolean truncated,
            String visibility,
            String visibilityReason,
            CameraVisibilityReport visibilityReport,
            String distanceBucket,
            String freshnessState,
            String anchorConfidenceLevel,
            Boolean anchorArReady,
            Boolean publicMemoryEligible,
            String mediaStatus,
            String moderationStatus,
            Double distanceMeters) {
    }

    private record ContextSnapshot(String baselineKey, Map<String, ContextSignal> signals) {
    }
}
