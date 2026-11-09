package tech.kayys.jezaku.rewards;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public final class RewardDtos {
    private RewardDtos() {
    }

    public record RewardEventRequest(
            String userId,
            String action,
            String sourceType,
            String sourceId,
            Instant occurredAt) {
    }

    public record BadgeResponse(
            String userId,
            String badgeId,
            String title,
            String description,
            String category,
            Instant earnedAt) {
    }

    public record BadgeDefinitionResponse(
            String badgeId,
            String title,
            String description,
            String category,
            int priority) {
    }

    public record RewardEventResponse(
            String eventId,
            String userId,
            String action,
            String sourceType,
            String sourceId,
            int xpAwarded,
            int totalXp,
            int level,
            List<BadgeResponse> badgesAwarded,
            boolean duplicate,
            Instant occurredAt,
            Instant createdAt) {
    }

    public record RewardProfileResponse(
            String userId,
            int totalXp,
            int level,
            int levelProgressXp,
            int nextLevelXp,
            int streakDays,
            LocalDate lastActivityDate,
            int badgeCount,
            List<BadgeResponse> badges,
            List<RewardEventResponse> recentEvents) {
    }

    public record UserBadgesResponse(String userId, int count, List<BadgeResponse> badges) {
    }

    public record BadgeCatalogResponse(int count, List<BadgeDefinitionResponse> badges) {
    }

    public record LeaderboardEntry(
            int rank,
            String userId,
            int xp,
            int level,
            int badgeCount,
            int streakDays) {
    }

    public record LeaderboardResponse(String scope, int count, List<LeaderboardEntry> entries) {
    }
}
