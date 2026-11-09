package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores group metadata used by circle membership and scoped content workflows.
 */
record SocialGroupRecord(
        String groupId,
        String name,
        String visibility,
        Instant createdAt) {
}
