package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimap;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapBadge;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapCluster;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapExpansion;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapLayerClip;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapLayerControl;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapPin;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapRing;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.geo.GeoMath.RelativeOffset;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import static tech.kayys.jezaku.geo.GeoMath.relativeBearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffset;
import static tech.kayys.jezaku.geo.GeoMath.round1;
import static tech.kayys.jezaku.geo.GeoMath.round2;

final class CameraMinimapViewports {
    private static final double CLUSTER_DISTANCE_THRESHOLD = 0.12;

    private CameraMinimapViewports() {
    }

    static CameraMinimap from(
            CameraTelemetry telemetry,
            CameraContextSummary summary,
            List<CameraLayer> layers,
            int visibleDotCount) {
        return from(telemetry, summary, layers, visibleDotCount, CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER);
    }

    static CameraMinimap from(
            CameraTelemetry telemetry,
            CameraContextSummary summary,
            List<CameraLayer> layers,
            int visibleDotCount,
            int pinLimitPerLayer) {
        double northRelativeBearingDegrees = relativeBearingDegrees(0.0, telemetry.orientationDegrees());
        RelativeOffset north = relativeOffset(telemetry.radiusMeters(), northRelativeBearingDegrees,
                telemetry.radiusMeters());
        List<CameraMinimapPin> allPins = pins(layers);
        List<CameraMinimapPin> pins = clippedPins(allPins, pinLimitPerLayer);
        List<CameraMinimapLayerClip> layerClips = layerClips(layers, allPins, pins, pinLimitPerLayer);
        int clippedPinCount = layerClips.stream().mapToInt(CameraMinimapLayerClip::clippedPinCount).sum();
        return new CameraMinimap(
                "heading_up",
                telemetry.position(),
                telemetry.radiusMeters(),
                telemetry.orientationDegrees(),
                northRelativeBearingDegrees,
                north.x(),
                north.y(),
                rings(telemetry.radiusMeters()),
                pins,
                clusters(pins),
                layerControls(layers),
                badges(layers, summary, clippedPinCount),
                layerClips,
                visibilityReports(layers),
                clippedPinCount > 0,
                clippedPinCount,
                visibleDotCount,
                summary.totalAvailableDots(),
                summary.perimeterCount(),
                summary.truncatedLayerCount() > 0);
    }

    static CameraMinimapExpansion expansion(
            CameraTelemetry telemetry,
            List<CameraLayer> layers,
            int pinLimitPerLayer,
            String layer) {
        String selectedLayer = normalizedLayer(layer);
        List<CameraMinimapPin> allPins = pins(layers);
        List<CameraMinimapPin> visiblePins = clippedPins(allPins, pinLimitPerLayer);
        List<CameraMinimapPin> hiddenPins = hiddenPins(allPins, visiblePins);
        List<CameraMinimapPin> filteredAllPins = filterPins(allPins, selectedLayer);
        List<CameraMinimapPin> filteredVisiblePins = filterPins(visiblePins, selectedLayer);
        List<CameraMinimapPin> filteredHiddenPins = filterPins(hiddenPins, selectedLayer);
        List<CameraMinimapLayerClip> filteredLayerClips = filterLayerClips(
                layerClips(layers, allPins, visiblePins, pinLimitPerLayer),
                selectedLayer);
        return new CameraMinimapExpansion(
                "heading_up",
                telemetry.position(),
                telemetry.radiusMeters(),
                telemetry.orientationDegrees(),
                Math.max(0, pinLimitPerLayer),
                selectedLayer,
                filteredLayerClips,
                filteredVisiblePins,
                filteredHiddenPins,
                filteredVisiblePins.size(),
                filteredHiddenPins.size(),
                filteredAllPins.size(),
                !filteredHiddenPins.isEmpty());
    }

    private static List<CameraMinimapRing> rings(double radiusMeters) {
        return List.of(
                ring(radiusMeters, 0.25),
                ring(radiusMeters, 0.5),
                ring(radiusMeters, 1.0));
    }

    private static CameraMinimapRing ring(double radiusMeters, double ratio) {
        double ringRadius = round1(radiusMeters * ratio);
        return new CameraMinimapRing(ringRadius, round2(ratio), label(ringRadius));
    }

    private static String label(double meters) {
        if (meters == Math.rint(meters)) {
            return (long) meters + " m";
        }
        return meters + " m";
    }

    private static List<CameraMinimapLayerControl> layerControls(List<CameraLayer> layers) {
        return layers.stream()
                .map(CameraMinimapViewports::layerControl)
                .sorted(Comparator.comparingInt(CameraMinimapLayerControl::priority).reversed()
                        .thenComparing(CameraMinimapLayerControl::layer))
                .toList();
    }

    private static CameraMinimapLayerControl layerControl(CameraLayer layer) {
        return new CameraMinimapLayerControl(
                layer.layer(),
                layerLabel(layer.layer()),
                displayMode(layer.layer()),
                layer.status(),
                true,
                true,
                layer.count(),
                layer.totalAvailable(),
                layer.truncated(),
                layerPriority(layer.layer()));
    }

    private static List<CameraMinimapBadge> badges(
            List<CameraLayer> layers,
            CameraContextSummary summary,
            int clippedPinCount) {
        List<CameraMinimapBadge> badges = new ArrayList<>();
        int safetyAlertCount = safetyAlertCount(layers);
        if (safetyAlertCount > 0) {
            int safetyPriority = highestSafetyPriority(layers);
            badges.add(new CameraMinimapBadge(
                    "safety",
                    "Safety",
                    safetyAlertCount,
                    safetySeverity(safetyPriority),
                    safetyPriority));
        }
        int livePeopleCount = livePeopleCount(layers);
        if (livePeopleCount > 0) {
            badges.add(new CameraMinimapBadge("live_people", "Live", livePeopleCount, "active", 700));
        }
        int peopleCount = layerCount(layers, "people");
        if (peopleCount > 0) {
            badges.add(new CameraMinimapBadge("people", "People", peopleCount, "normal", 600));
        }
        if (summary.needsRefinementMemoryCount() > 0) {
            badges.add(new CameraMinimapBadge(
                    "anchor_refinement",
                    "Refine",
                    summary.needsRefinementMemoryCount(),
                    "warning",
                    500));
        }
        if (summary.arReadyMemoryCount() > 0) {
            badges.add(new CameraMinimapBadge(
                    "ar_ready_memories",
                    "AR Ready",
                    summary.arReadyMemoryCount(),
                    "active",
                    450));
        }
        int memoryCount = layerCount(layers, "memories");
        if (memoryCount > 0) {
            badges.add(new CameraMinimapBadge("memories", "Memories", memoryCount, "normal", 400));
        }
        int hiddenCount = hiddenCount(layers) + Math.max(0, clippedPinCount);
        if (hiddenCount > 0) {
            badges.add(new CameraMinimapBadge("hidden", "More", hiddenCount, "info", 350));
        }
        if (summary.perimeterCount() > 0) {
            badges.add(new CameraMinimapBadge("perimeter", "Perimeter", summary.perimeterCount(), "info", 300));
        }
        return badges.stream()
                .sorted(Comparator.comparingInt(CameraMinimapBadge::priority).reversed()
                        .thenComparing(CameraMinimapBadge::type))
                .toList();
    }

    private static List<CameraMinimapPin> clippedPins(List<CameraMinimapPin> pins, int pinLimitPerLayer) {
        if (pinLimitPerLayer <= 0) {
            return pins;
        }
        List<CameraMinimapPin> result = new ArrayList<>();
        for (CameraMinimapPin pin : pins) {
            if (layerPinCount(result, pin.layer()) < pinLimitPerLayer) {
                result.add(pin);
            }
        }
        return List.copyOf(result);
    }

    private static List<CameraMinimapPin> hiddenPins(
            List<CameraMinimapPin> allPins,
            List<CameraMinimapPin> visiblePins) {
        return allPins.stream()
                .filter(pin -> !visiblePins.contains(pin))
                .toList();
    }

    private static List<CameraMinimapPin> filterPins(List<CameraMinimapPin> pins, String layer) {
        if (layer == null) {
            return pins;
        }
        return pins.stream()
                .filter(pin -> layer.equals(pin.layer()))
                .toList();
    }

    private static List<CameraMinimapLayerClip> filterLayerClips(
            List<CameraMinimapLayerClip> layerClips,
            String layer) {
        if (layer == null) {
            return layerClips;
        }
        return layerClips.stream()
                .filter(clip -> layer.equals(clip.layer()))
                .toList();
    }

    private static String normalizedLayer(String layer) {
        if (layer == null || layer.isBlank()) {
            return null;
        }
        return layer.trim();
    }

    private static List<CameraMinimapLayerClip> layerClips(
            List<CameraLayer> layers,
            List<CameraMinimapPin> allPins,
            List<CameraMinimapPin> visiblePins,
            int pinLimitPerLayer) {
        return layers.stream()
                .sorted(Comparator.comparingInt((CameraLayer layer) -> layerPriority(layer.layer())).reversed()
                        .thenComparing(CameraLayer::layer))
                .map(layer -> layerClip(layer.layer(), allPins, visiblePins, pinLimitPerLayer))
                .toList();
    }

    private static CameraMinimapLayerClip layerClip(
            String layer,
            List<CameraMinimapPin> allPins,
            List<CameraMinimapPin> visiblePins,
            int pinLimitPerLayer) {
        int availableCount = layerPinCount(allPins, layer);
        int visibleCount = layerPinCount(visiblePins, layer);
        int clippedCount = Math.max(0, availableCount - visibleCount);
        return new CameraMinimapLayerClip(
                layer,
                Math.max(0, pinLimitPerLayer),
                availableCount,
                visibleCount,
                clippedCount,
                clippedCount > 0);
    }

    private static int layerPinCount(List<CameraMinimapPin> pins, String layer) {
        return (int) pins.stream()
                .filter(pin -> pin.layer().equals(layer))
                .count();
    }

    private static List<CameraMinimapPin> pins(List<CameraLayer> layers) {
        return layers.stream()
                .flatMap(layer -> layer.dots().stream())
                .map(CameraMinimapViewports::pin)
                .sorted(Comparator.comparingInt(CameraMinimapPin::priority).reversed()
                        .thenComparingDouble(CameraMinimapPin::distanceMeters)
                        .thenComparing(CameraMinimapPin::layer)
                        .thenComparing(CameraMinimapPin::targetId))
                .toList();
    }

    private static List<CameraVisibilityReport> visibilityReports(List<CameraLayer> layers) {
        return layers.stream()
                .map(CameraLayer::visibility)
                .filter(report -> report != null)
                .toList();
    }

    private static List<CameraMinimapCluster> clusters(List<CameraMinimapPin> pins) {
        List<ClusterBucket> buckets = new ArrayList<>();
        for (CameraMinimapPin pin : pins) {
            ClusterBucket bucket = nearestBucket(pin, buckets);
            if (bucket == null) {
                buckets.add(new ClusterBucket(pin));
            } else {
                bucket.add(pin);
            }
        }
        return buckets.stream()
                .filter(bucket -> bucket.count() > 1)
                .sorted(Comparator.comparingInt(ClusterBucket::priority).reversed()
                        .thenComparing(Comparator.comparingInt(ClusterBucket::count).reversed())
                        .thenComparingDouble(ClusterBucket::distanceFromCenter))
                .map(CameraMinimapViewports::cluster)
                .toList();
    }

    private static ClusterBucket nearestBucket(CameraMinimapPin pin, List<ClusterBucket> buckets) {
        ClusterBucket best = null;
        double bestDistance = Double.MAX_VALUE;
        for (ClusterBucket bucket : buckets) {
            double distance = bucket.distanceTo(pin);
            if (distance <= CLUSTER_DISTANCE_THRESHOLD && distance < bestDistance) {
                best = bucket;
                bestDistance = distance;
            }
        }
        return best;
    }

    private static CameraMinimapCluster cluster(ClusterBucket bucket) {
        return new CameraMinimapCluster(
                "cluster_" + bucket.primaryLayer() + "_" + bucket.primaryTargetId(),
                round2(bucket.x()),
                round2(bucket.y()),
                bucket.count(),
                bucket.layerCount("safety"),
                bucket.layerCount("people"),
                bucket.layerCount("memories"),
                bucket.otherCount(),
                bucket.perimeter(),
                bucket.priority(),
                bucket.count() + " nearby");
    }

    private static CameraMinimapPin pin(CameraDot dot) {
        return new CameraMinimapPin(
                dot.layer(),
                dot.targetType(),
                dot.targetId(),
                dot.mediaId(),
                displayMode(dot),
                dot.title(),
                dot.visibility(),
                dot.visibilityReason(),
                dot.thumbnailUrl(),
                dot.publicMemoryEligible(),
                dot.anchor(),
                dot.relativeX(),
                dot.relativeY(),
                dot.distanceMeters(),
                dot.distanceRatio(),
                dot.relativeBearingDegrees(),
                dot.distanceRatio() >= 1.0 || "perimeter".equals(dot.distanceBucket()),
                priority(dot),
                href(dot));
    }

    private static String displayMode(CameraDot dot) {
        if ("memories".equals(dot.layer())) {
            return memoryDisplayMode(dot);
        }
        return displayMode(dot.layer());
    }

    private static String memoryDisplayMode(CameraDot dot) {
        if (!Boolean.TRUE.equals(dot.publicMemoryEligible())) {
            return "photo_hint";
        }
        if (dot.anchor() == null) {
            return "photo";
        }
        if (dot.anchor().arReady()) {
            return "ar_photo";
        }
        return "photo_hint";
    }

    private static String displayMode(String layer) {
        return switch (layer) {
            case "safety" -> "safety_zone";
            case "people" -> "avatar";
            case "memories" -> "photo";
            default -> "dot";
        };
    }

    private static int priority(CameraDot dot) {
        if ("safety".equals(dot.layer())) {
            return safetyPriority(dot);
        }
        if ("people".equals(dot.layer())) {
            return "live_session".equals(dot.source()) ? 700 : 600;
        }
        return layerPriority(dot.layer());
    }

    private static int layerPriority(String layer) {
        return switch (layer) {
            case "safety" -> 900;
            case "people" -> 600;
            case "memories" -> 400;
            default -> 100;
        };
    }

    private static String layerLabel(String layer) {
        return switch (layer) {
            case "safety" -> "Safety";
            case "people" -> "People";
            case "memories" -> "Memories";
            default -> layer;
        };
    }

    private static int layerCount(List<CameraLayer> layers, String layerName) {
        return layers.stream()
                .filter(layer -> layer.layer().equals(layerName))
                .mapToInt(CameraLayer::count)
                .sum();
    }

    private static int livePeopleCount(List<CameraLayer> layers) {
        return layers.stream()
                .filter(layer -> "people".equals(layer.layer()))
                .mapToInt(layer -> layer.summary() == null
                        ? livePeopleDotCount(layer)
                        : Math.max(layer.summary().liveCount(), livePeopleDotCount(layer)))
                .sum();
    }

    private static int livePeopleDotCount(CameraLayer layer) {
        return (int) layer.dots().stream()
                .filter(dot -> "live_session".equals(dot.source()))
                .count();
    }

    private static int hiddenCount(List<CameraLayer> layers) {
        return layers.stream()
                .mapToInt(CameraMinimapViewports::hiddenCount)
                .sum();
    }

    private static int hiddenCount(CameraLayer layer) {
        if (layer.visibility() != null && !"camera_local".equals(layer.visibility().mode())) {
            return Math.max(0, layer.visibility().hiddenCandidateCount());
        }
        return Math.max(0, layer.totalAvailable() - layer.count());
    }

    private static int safetyAlertCount(List<CameraLayer> layers) {
        return (int) layers.stream()
                .filter(layer -> "safety".equals(layer.layer()))
                .flatMap(layer -> layer.dots().stream())
                .filter(dot -> safetyPriority(dot) >= 500)
                .count();
    }

    private static int highestSafetyPriority(List<CameraLayer> layers) {
        return layers.stream()
                .filter(layer -> "safety".equals(layer.layer()))
                .flatMap(layer -> layer.dots().stream())
                .mapToInt(CameraMinimapViewports::safetyPriority)
                .max()
                .orElse(250);
    }

    private static String safetySeverity(int priority) {
        if (priority >= 1000) {
            return "critical";
        }
        if (priority >= 800) {
            return "warning";
        }
        return "info";
    }

    private static int safetyPriority(CameraDot dot) {
        String action = firstActionType(dot);
        return switch (action) {
            case "blocked" -> 1000;
            case "notify_guardian", "near_restricted_area" -> 800;
            case "quiet_mode", "near_quiet_area" -> 500;
            case "inside_safe_area" -> 300;
            default -> 250;
        };
    }

    private static String firstActionType(CameraDot dot) {
        return dot.actions().isEmpty() ? "" : dot.actions().getFirst().type();
    }

    private static String href(CameraDot dot) {
        CameraAction action = dot.actions().isEmpty() ? null : dot.actions().getFirst();
        return action == null ? null : action.href();
    }

    private static final class ClusterBucket {
        private final List<CameraMinimapPin> pins = new ArrayList<>();
        private double x;
        private double y;

        ClusterBucket(CameraMinimapPin pin) {
            add(pin);
        }

        void add(CameraMinimapPin pin) {
            pins.add(pin);
            x = pins.stream().mapToDouble(CameraMinimapPin::x).average().orElse(0.0);
            y = pins.stream().mapToDouble(CameraMinimapPin::y).average().orElse(0.0);
        }

        int count() {
            return pins.size();
        }

        double x() {
            return x;
        }

        double y() {
            return y;
        }

        int priority() {
            return pins.stream()
                    .mapToInt(CameraMinimapPin::priority)
                    .max()
                    .orElse(0);
        }

        int layerCount(String layer) {
            return (int) pins.stream()
                    .filter(pin -> pin.layer().equals(layer))
                    .count();
        }

        int otherCount() {
            return count() - layerCount("safety") - layerCount("people") - layerCount("memories");
        }

        boolean perimeter() {
            return pins.stream().anyMatch(CameraMinimapPin::perimeter);
        }

        String primaryLayer() {
            return primary().layer();
        }

        String primaryTargetId() {
            return primary().targetId();
        }

        double distanceTo(CameraMinimapPin pin) {
            return Math.hypot(x - pin.x(), y - pin.y());
        }

        double distanceFromCenter() {
            return Math.hypot(x, y);
        }

        private CameraMinimapPin primary() {
            return pins.stream()
                    .max(Comparator.comparingInt(CameraMinimapPin::priority)
                            .thenComparing(pin -> -pin.distanceMeters()))
                    .orElseThrow();
        }
    }
}
