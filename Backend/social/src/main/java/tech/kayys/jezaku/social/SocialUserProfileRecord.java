package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores profile metadata that powers user cards, search, and profile screens.
 */
record SocialUserProfileRecord(
        String userId,
        String handle,
        String displayName,
        String bio,
        String avatarUrl,
        String websiteUrl,
        String locationLabel,
        String profileVisibility,
        Instant createdAt,
        Instant updatedAt) {
}
