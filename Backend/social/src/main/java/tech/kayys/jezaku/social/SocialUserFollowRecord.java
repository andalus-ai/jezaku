package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a directed follow edge from one user to another user.
 */
record SocialUserFollowRecord(String followerId, String followedUserId, Instant createdAt) {
}
