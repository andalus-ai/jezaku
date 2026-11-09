package tech.kayys.jezaku.events;

import java.time.Instant;

record InviteRecord(
        String id,
        String eventId,
        String inviterId,
        String inviteeUserId,
        String message,
        String status,
        Instant createdAt,
        Instant updatedAt) {
}
