package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraAdvisory;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;

import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Objects;

final class CameraContextSummaries {
    private CameraContextSummaries() {
    }

    static CameraContextSummary from(List<CameraLayer> layers, List<CameraAdvisory> advisories) {
        return new CameraContextSummary(
                layers.size(),
                (int) layers.stream().filter(layer -> "ready".equals(layer.status())).count(),
                layers.stream().mapToInt(CameraLayer::totalAvailable).sum(),
                (int) layers.stream().filter(CameraLayer::truncated).count(),
                (int) layers.stream().map(CameraLayer::visibility).filter(Objects::nonNull).count(),
                layers.stream()
                        .map(CameraLayer::visibility)
                        .filter(Objects::nonNull)
                        .mapToInt(report -> Math.max(0, report.hiddenCandidateCount()))
                        .sum(),
                (int) layers.stream()
                        .map(CameraLayer::visibility)
                        .filter(Objects::nonNull)
                        .filter(CameraContextSummaries::visibilityAudienceNeedsAttention)
                        .count(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::perimeterCount).sum(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::liveCount).sum(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::freshCount).sum(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::staticCount).sum(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::arReadyMemoryCount).sum(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::lowConfidenceMemoryCount).sum(),
                layers.stream().map(CameraLayer::summary).mapToInt(CameraLayerSummary::needsRefinementMemoryCount).sum(),
                countBySeverity(advisories, "critical"),
                countBySeverity(advisories, "warning"),
                countBySeverity(advisories, "info"),
                countByDisplayMode(advisories, "blocking_banner"),
                highestAdvisoryPriority(advisories),
                nearestDistance(layers),
                farthestDistance(layers));
    }

    private static boolean visibilityAudienceNeedsAttention(CameraVisibilityReport report) {
        String health = report.audienceHealth() == null
                ? "unknown"
                : report.audienceHealth().trim().toLowerCase(Locale.ROOT);
        return report.audienceFallback() || !"healthy".equals(health);
    }

    private static int countBySeverity(List<CameraAdvisory> advisories, String severity) {
        return (int) advisories.stream()
                .filter(advisory -> severity.equals(advisory.severity()))
                .count();
    }

    private static int countByDisplayMode(List<CameraAdvisory> advisories, String displayMode) {
        return (int) advisories.stream()
                .filter(advisory -> displayMode.equals(advisory.displayMode()))
                .count();
    }

    private static Integer highestAdvisoryPriority(List<CameraAdvisory> advisories) {
        return advisories.stream()
                .max(Comparator.comparingInt(CameraAdvisory::priority))
                .map(CameraAdvisory::priority)
                .orElse(null);
    }

    private static Double nearestDistance(List<CameraLayer> layers) {
        return layers.stream()
                .map(CameraLayer::summary)
                .map(CameraLayerSummary::nearestDistanceMeters)
                .filter(Objects::nonNull)
                .min(Double::compareTo)
                .orElse(null);
    }

    private static Double farthestDistance(List<CameraLayer> layers) {
        return layers.stream()
                .map(CameraLayer::summary)
                .map(CameraLayerSummary::farthestDistanceMeters)
                .filter(Objects::nonNull)
                .max(Double::compareTo)
                .orElse(null);
    }
}
