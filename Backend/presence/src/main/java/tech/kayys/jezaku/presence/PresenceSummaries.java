package tech.kayys.jezaku.presence;

import tech.kayys.jezaku.presence.PresenceDtos.MinimapDot;
import tech.kayys.jezaku.presence.PresenceDtos.NearbyPresence;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceSummary;

import java.util.Comparator;
import java.util.List;

final class PresenceSummaries {
    private PresenceSummaries() {
    }

    static PresenceSummary nearby(List<NearbyPresence> users) {
        return from(users.stream()
                .map(user -> new SummaryPoint(
                        user.distanceMeters(),
                        user.freshnessState(),
                        user.expiresInSeconds(),
                        user.perimeter()))
                .toList());
    }

    static PresenceSummary minimap(List<MinimapDot> dots) {
        return from(dots.stream()
                .map(dot -> new SummaryPoint(
                        dot.distanceMeters(),
                        dot.freshnessState(),
                        dot.expiresInSeconds(),
                        dot.perimeter()))
                .toList());
    }

    private static PresenceSummary from(List<SummaryPoint> points) {
        Double nearest = points.stream()
                .min(Comparator.comparingDouble(SummaryPoint::distanceMeters))
                .map(SummaryPoint::distanceMeters)
                .orElse(null);
        Double farthest = points.stream()
                .max(Comparator.comparingDouble(SummaryPoint::distanceMeters))
                .map(SummaryPoint::distanceMeters)
                .orElse(null);
        return new PresenceSummary(
                points.size(),
                countFreshness(points, "fresh"),
                countFreshness(points, "recent"),
                countFreshness(points, "stale"),
                expiringSoonCount(points),
                perimeterCount(points),
                nearest,
                farthest);
    }

    private static int countFreshness(List<SummaryPoint> points, String freshnessState) {
        return (int) points.stream()
                .filter(point -> freshnessState.equals(point.freshnessState()))
                .count();
    }

    private static int expiringSoonCount(List<SummaryPoint> points) {
        return (int) points.stream()
                .filter(point -> point.expiresInSeconds() > 0)
                .filter(point -> point.expiresInSeconds() <= 30)
                .count();
    }

    private static int perimeterCount(List<SummaryPoint> points) {
        return (int) points.stream()
                .filter(SummaryPoint::perimeter)
                .count();
    }

    private record SummaryPoint(
            double distanceMeters,
            String freshnessState,
            long expiresInSeconds,
            boolean perimeter) {
    }
}
