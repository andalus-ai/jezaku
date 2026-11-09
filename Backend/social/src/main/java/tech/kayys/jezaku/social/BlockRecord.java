package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a directed block edge used by relationship, feed, and audience policy checks.
 */
record BlockRecord(String userId, String blockedUserId, String reason, Instant createdAt) {
}
