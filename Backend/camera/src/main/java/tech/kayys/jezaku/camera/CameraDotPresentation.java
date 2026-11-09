package tech.kayys.jezaku.camera;

final class CameraDotPresentation {
    private CameraDotPresentation() {
    }

    static String distanceBucket(double distanceRatio) {
        if (distanceRatio >= 0.9) {
            return "perimeter";
        }
        if (distanceRatio >= 0.6) {
            return "far";
        }
        if (distanceRatio >= 0.25) {
            return "mid";
        }
        return "near";
    }

    static String freshnessState(long ageSeconds, Long expiresInSeconds) {
        if (expiresInSeconds == null) {
            return "static";
        }
        if (expiresInSeconds <= 0) {
            return "expired";
        }
        if (ageSeconds <= 30) {
            return "fresh";
        }
        if (ageSeconds <= 120) {
            return "recent";
        }
        return "stale";
    }
}
