package tech.kayys.jezaku.events;

import tech.kayys.jezaku.events.EventDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

record EventRecord(
        String id,
        String organizerId,
        String title,
        String description,
        String category,
        String visibility,
        String placeId,
        GeoPoint center,
        double checkInRadiusMeters,
        Instant startsAt,
        Instant endsAt,
        int capacity,
        List<String> tags,
        List<String> anchorIds,
        String status,
        Instant createdAt,
        Instant updatedAt) {
    EventRecord withStatus(String status, Instant updatedAt) {
        return new EventRecord(id, organizerId, title, description, category, visibility, placeId, center,
                checkInRadiusMeters, startsAt, endsAt, capacity, tags, anchorIds, status, createdAt, updatedAt);
    }
}
