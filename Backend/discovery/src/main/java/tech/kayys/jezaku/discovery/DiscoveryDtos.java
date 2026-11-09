package tech.kayys.jezaku.discovery;

import java.time.Instant;
import java.util.List;

public final class DiscoveryDtos {
    private DiscoveryDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record DiscoveryItem(
            String itemId,
            String targetType,
            String targetId,
            String title,
            String subtitle,
            String thumbnailUrl,
            String category,
            GeoPoint position,
            double distanceMeters,
            double bearingDegrees,
            double score,
            int engagementScore,
            List<String> tags,
            Instant startsAt,
            Instant updatedAt) {
    }

    public record DiscoveryListResponse(
            String viewerId,
            double radiusMeters,
            int count,
            List<DiscoveryItem> items) {
    }

    public record SearchResponse(String query, int count, List<DiscoveryItem> items) {
    }

    public record FeedbackRequest(String userId, String targetType, String targetId, String action) {
    }

    public record FeedbackResponse(
            String userId,
            String targetType,
            String targetId,
            String action,
            Instant createdAt,
            Instant updatedAt) {
    }
}
