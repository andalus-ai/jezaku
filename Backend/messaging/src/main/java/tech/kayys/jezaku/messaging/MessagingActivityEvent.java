package tech.kayys.jezaku.messaging;

import java.time.Instant;

record MessagingActivityEvent(
        String activityId,
        String threadId,
        String actorUserId,
        String activityType,
        String targetId,
        String detail,
        Instant createdAt) {
}
