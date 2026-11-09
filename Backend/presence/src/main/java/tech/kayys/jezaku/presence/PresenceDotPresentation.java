package tech.kayys.jezaku.presence;

import java.time.Duration;
import java.time.Instant;

final class PresenceDotPresentation {
    private PresenceDotPresentation() {
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

    static boolean perimeter(double distanceRatio) {
        return distanceRatio >= 0.9;
    }

    static String freshnessState(long ageSeconds, long expiresInSeconds) {
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

    static long secondsSince(Instant value, Instant now) {
        return Math.max(0, Duration.between(value, now).toSeconds());
    }

    static long secondsUntil(Instant value, Instant now) {
        return Math.max(0, Duration.between(now, value).toSeconds());
    }
}
