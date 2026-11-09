package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a content comment, including optional parent linkage for threaded replies.
 */
record SocialCommentRecord(
        String commentId,
        String contentId,
        String authorId,
        String text,
        String parentCommentId,
        Instant createdAt) {
}
