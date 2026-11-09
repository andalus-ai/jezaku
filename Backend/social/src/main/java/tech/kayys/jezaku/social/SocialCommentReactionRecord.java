package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's reaction to a specific comment.
 */
record SocialCommentReactionRecord(
        String commentId,
        String userId,
        String reactionType,
        Instant createdAt) {
}
