package tech.kayys.jezaku.events;

import java.time.Instant;

record RsvpRecord(String eventId, String userId, String status, Instant updatedAt) {
}
