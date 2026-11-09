package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a family relationship edge between two users.
 */
record FamilyLinkRecord(
        String firstUserId,
        String secondUserId,
        String relationship,
        Instant createdAt) {
}
