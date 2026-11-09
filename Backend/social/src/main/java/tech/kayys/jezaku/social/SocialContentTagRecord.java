package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a normalized hashtag attached to a content item.
 */
record SocialContentTagRecord(
        String contentId,
        String tag,
        Instant createdAt) {
}
