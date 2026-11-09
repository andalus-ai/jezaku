package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Describes a friendship edge returned by graph traversal read models.
 */
record FriendConnection(String userId, Instant since, boolean closeFriend) {
}
