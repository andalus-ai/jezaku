package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores community metadata used by membership, discovery, and scoped content workflows.
 */
record SocialCommunityRecord(
        String communityId,
        String name,
        String visibility,
        Instant createdAt) {
}
