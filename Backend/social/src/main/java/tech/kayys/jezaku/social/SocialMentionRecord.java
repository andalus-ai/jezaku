package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user mention extracted from content or comments.
 */
record SocialMentionRecord(
        String mentionId,
        String contentId,
        String commentId,
        String actorId,
        String mentionedUserId,
        String sourceType,
        Instant createdAt) {
}
