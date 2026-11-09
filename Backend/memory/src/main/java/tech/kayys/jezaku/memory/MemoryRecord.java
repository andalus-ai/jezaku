package tech.kayys.jezaku.memory;

import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

record MemoryRecord(
        String id,
        String ownerId,
        String mediaId,
        String mediaStatus,
        String moderationStatus,
        String mediaUrl,
        String thumbnailUrl,
        String caption,
        GeoPoint position,
        Double headingDegrees,
        Double compassDegrees,
        Double pitchDegrees,
        Double rollDegrees,
        Double gpsAccuracyMeters,
        String anchorType,
        String visibility,
        List<String> tags,
        String placeId,
        Instant capturedAt,
        Instant createdAt) {
    MemoryRecord withMediaSnapshot(String mediaStatus, String moderationStatus) {
        return new MemoryRecord(
                id,
                ownerId,
                mediaId,
                mediaStatus,
                moderationStatus,
                mediaUrl,
                thumbnailUrl,
                caption,
                position,
                headingDegrees,
                compassDegrees,
                pitchDegrees,
                rollDegrees,
                gpsAccuracyMeters,
                anchorType,
                visibility,
                tags,
                placeId,
                capturedAt,
                createdAt);
    }
}
