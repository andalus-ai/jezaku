package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;

import java.util.Comparator;
import java.util.List;

final class CameraLayerSummaries {
    private CameraLayerSummaries() {
    }

    static CameraLayerSummary from(List<CameraDot> dots) {
        Double nearest = dots.stream()
                .min(Comparator.comparingDouble(CameraDot::distanceMeters))
                .map(CameraDot::distanceMeters)
                .orElse(null);
        Double farthest = dots.stream()
                .max(Comparator.comparingDouble(CameraDot::distanceMeters))
                .map(CameraDot::distanceMeters)
                .orElse(null);
        return new CameraLayerSummary(
                nearest,
                farthest,
                countByDistanceBucket(dots, "perimeter"),
                countBySource(dots, "live_session"),
                countByFreshness(dots, "fresh"),
                countByFreshness(dots, "static"),
                arReadyMemoryCount(dots),
                lowConfidenceMemoryCount(dots),
                needsRefinementMemoryCount(dots));
    }

    private static int countByDistanceBucket(List<CameraDot> dots, String distanceBucket) {
        return (int) dots.stream()
                .filter(dot -> distanceBucket.equals(dot.distanceBucket()))
                .count();
    }

    private static int countBySource(List<CameraDot> dots, String source) {
        return (int) dots.stream()
                .filter(dot -> source.equals(dot.source()))
                .count();
    }

    private static int countByFreshness(List<CameraDot> dots, String freshnessState) {
        return (int) dots.stream()
                .filter(dot -> freshnessState.equals(dot.freshnessState()))
                .count();
    }

    private static int arReadyMemoryCount(List<CameraDot> dots) {
        return (int) dots.stream()
                .filter(CameraLayerSummaries::memoryDot)
                .filter(dot -> Boolean.TRUE.equals(dot.publicMemoryEligible()))
                .filter(dot -> dot.anchor() != null && dot.anchor().arReady())
                .count();
    }

    private static int lowConfidenceMemoryCount(List<CameraDot> dots) {
        return (int) dots.stream()
                .filter(CameraLayerSummaries::memoryDot)
                .filter(CameraLayerSummaries::lowConfidence)
                .count();
    }

    private static int needsRefinementMemoryCount(List<CameraDot> dots) {
        return (int) dots.stream()
                .filter(CameraLayerSummaries::memoryDot)
                .filter(CameraLayerSummaries::needsRefinement)
                .count();
    }

    private static boolean memoryDot(CameraDot dot) {
        return "memories".equals(dot.layer());
    }

    private static boolean lowConfidence(CameraDot dot) {
        if (dot.anchor() == null) {
            return false;
        }
        if (dot.anchor().confidence() != null) {
            return "low".equals(dot.anchor().confidence().level());
        }
        return "low".equals(dot.anchor().quality());
    }

    private static boolean needsRefinement(CameraDot dot) {
        if (dot.anchor() == null) {
            return false;
        }
        if (dot.anchor().confidence() != null) {
            return !dot.anchor().confidence().recommendedActions().isEmpty();
        }
        return !dot.anchor().arReady();
    }
}
