package tech.kayys.jezaku.events;

import java.time.Instant;

record CheckInRecord(String eventId, String userId, double distanceMeters, Instant checkedInAt) {
}
