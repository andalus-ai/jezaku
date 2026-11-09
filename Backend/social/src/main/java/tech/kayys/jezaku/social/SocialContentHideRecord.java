package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's hidden-content preference.
 */
record SocialContentHideRecord(
        String contentId,
        String userId,
        String reason,
        Instant createdAt) {
}
