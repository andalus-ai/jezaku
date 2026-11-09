package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's close-friend designation for an existing friendship.
 */
record CloseFriendRecord(String ownerId, String friendId, Instant createdAt) {
}
