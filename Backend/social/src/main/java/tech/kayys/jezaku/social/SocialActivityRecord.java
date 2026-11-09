package tech.kayys.jezaku.social;

import java.time.Instant;

/**
 * Stores a notification/activity event generated from social graph interactions.
 */
record SocialActivityRecord(
        String activityId,
        String eventType,
        String actorId,
        String recipientId,
        String contentId,
        String commentId,
        String reactionType,
        String message,
        Instant createdAt,
        boolean read) {
    SocialActivityRecord withRead(boolean read) {
        return new SocialActivityRecord(
                activityId,
                eventType,
                actorId,
                recipientId,
                contentId,
                commentId,
                reactionType,
                message,
                createdAt,
                read);
    }
}
