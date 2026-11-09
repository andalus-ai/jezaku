package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores the pending or resolved request that one user sends to become friends with another user.
 */
record FriendRequestRecord(
        String id,
        String fromUserId,
        String toUserId,
        String message,
        String status,
        Instant createdAt,
        Instant updatedAt) {
    FriendRequestRecord withStatus(String status, Instant updatedAt) {
        return new FriendRequestRecord(id, fromUserId, toUserId, message, status, createdAt, updatedAt);
    }
}
