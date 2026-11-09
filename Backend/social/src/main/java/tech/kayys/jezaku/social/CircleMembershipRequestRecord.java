package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a pending or resolved group/community membership request or invitation.
 */
record CircleMembershipRequestRecord(
        String requestId,
        String targetId,
        String targetType,
        String userId,
        String actorUserId,
        String requestType,
        String status,
        String message,
        Instant createdAt,
        Instant updatedAt) {
    CircleMembershipRequestRecord withStatus(String status, Instant updatedAt) {
        return new CircleMembershipRequestRecord(
                requestId,
                targetId,
                targetType,
                userId,
                actorUserId,
                requestType,
                status,
                message,
                createdAt,
                updatedAt);
    }
}
