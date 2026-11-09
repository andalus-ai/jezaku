package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's saved-content bookmark.
 */
record SocialSaveRecord(
        String contentId,
        String userId,
        Instant createdAt) {
}
