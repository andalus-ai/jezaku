package tech.kayys.jezaku.media;

import java.time.Instant;

record MediaModerationEvent(
        String eventId,
        String mediaId,
        String reviewerId,
        String moderationStatus,
        String previousStatus,
        String nextStatus,
        String reason,
        Instant createdAt) {
}
