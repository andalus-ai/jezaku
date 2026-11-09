package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's follow edge for a normalized hashtag.
 */
record SocialTagFollowRecord(
        String userId,
        String tag,
        Instant createdAt) {
}
