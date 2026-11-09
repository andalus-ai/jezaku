package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's share action for a content item.
 */
record SocialShareRecord(
        String shareId,
        String contentId,
        String userId,
        String message,
        Instant createdAt) {
}
