package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores an accepted bidirectional friendship between two users.
 */
record FriendshipRecord(String firstUserId, String secondUserId, Instant createdAt) {
}
