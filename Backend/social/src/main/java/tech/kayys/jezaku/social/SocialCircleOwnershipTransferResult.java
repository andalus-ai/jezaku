package tech.kayys.jezaku.social;

import java.time.Instant;

record SocialCircleOwnershipTransferResult(
        String targetId,
        String targetType,
        String previousOwnerId,
        String newOwnerId,
        String previousOwnerRole,
        String newOwnerRole,
        Instant transferredAt) {
}
