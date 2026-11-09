package tech.kayys.jezaku.events;

import java.time.Instant;

record EventActivityEvent(
        String activityId,
        String eventId,
        String actorUserId,
        String activityType,
        String targetUserId,
        String detail,
        Instant createdAt) {
}
