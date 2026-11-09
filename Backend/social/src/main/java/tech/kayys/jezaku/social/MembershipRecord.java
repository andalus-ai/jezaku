package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a user's role membership in a group or community.
 */
record MembershipRecord(
        String memberId,
        String targetId,
        String role,
        Instant createdAt) {
}
