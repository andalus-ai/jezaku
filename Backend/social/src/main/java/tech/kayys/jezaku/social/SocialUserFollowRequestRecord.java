package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a follow request and its moderation state for private profile flows.
 */
record SocialUserFollowRequestRecord(
        String followerId,
        String followedUserId,
        String status,
        Instant createdAt,
        Instant updatedAt) {
    SocialUserFollowRequestRecord withStatus(String status, Instant updatedAt) {
        return new SocialUserFollowRequestRecord(followerId, followedUserId, status, createdAt, updatedAt);
    }
}
