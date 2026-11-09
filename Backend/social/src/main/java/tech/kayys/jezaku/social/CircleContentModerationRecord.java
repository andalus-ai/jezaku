package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores moderation decisions for content posted into a group or community.
 */
record CircleContentModerationRecord(
        String moderationId,
        String contentId,
        String targetId,
        String targetType,
        String actorUserId,
        String action,
        String status,
        String reason,
        Instant createdAt,
        Instant updatedAt) {
}
