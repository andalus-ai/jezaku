package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores the canonical content metadata for posts, photos, and scoped social media items.
 */
record SocialContentRecord(
        String contentId,
        String ownerId,
        String contentType,
        String scope,
        String targetId,
        String caption,
        Instant createdAt) {
}
