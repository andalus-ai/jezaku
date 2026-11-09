package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's reaction to a content item.
 */
record SocialReactionRecord(
        String contentId,
        String userId,
        String reactionType,
        Instant createdAt) {
}
