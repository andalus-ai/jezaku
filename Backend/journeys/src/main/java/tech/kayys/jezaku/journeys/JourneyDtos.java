package tech.kayys.jezaku.journeys;

import java.time.Instant;
import java.util.List;

public final class JourneyDtos {
    private JourneyDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record JourneyCheckpoint(
            String checkpointId,
            int orderIndex,
            String title,
            String description,
            String targetType,
            String targetId,
            GeoPoint position,
            double radiusMeters,
            boolean required) {
    }

    public record JourneyResponse(
            String journeyId,
            String title,
            String description,
            String category,
            String visibility,
            GeoPoint startPosition,
            double estimatedDistanceMeters,
            int estimatedMinutes,
            List<String> tags,
            List<JourneyCheckpoint> checkpoints,
            String rewardBadgeId,
            String rewardBadgeTitle,
            String status,
            double distanceMeters,
            double bearingDegrees,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record JourneyListResponse(String viewerId, double radiusMeters, int count, List<JourneyResponse> journeys) {
    }

    public record JourneyStartRequest(String userId) {
    }

    public record CheckpointCompleteRequest(
            String userId,
            GeoPoint position,
            String evidenceTargetType,
            String evidenceTargetId) {
    }

    public record CheckpointProgress(
            String checkpointId,
            int orderIndex,
            String title,
            boolean completed,
            Instant completedAt) {
    }

    public record BadgeResponse(
            String userId,
            String badgeId,
            String title,
            String journeyId,
            Instant awardedAt) {
    }

    public record JourneyProgressResponse(
            String sessionId,
            String journeyId,
            String userId,
            String status,
            int checkpointCount,
            int completedCount,
            List<CheckpointProgress> checkpoints,
            BadgeResponse awardedBadge,
            Instant startedAt,
            Instant updatedAt,
            Instant completedAt) {
    }

    public record UserJourneysResponse(String userId, int count, List<JourneyProgressResponse> journeys) {
    }

    public record UserBadgesResponse(String userId, int count, List<BadgeResponse> badges) {
    }
}
