package tech.kayys.jezaku.presence;

import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;

import java.time.Instant;

record PresenceRecord(
        String userId,
        String displayName,
        String avatarUrl,
        GeoPoint position,
        Double headingDegrees,
        Double compassDegrees,
        Double speedMetersPerSecond,
        String visibility,
        int shareRadiusMeters,
        String statusMessage,
        Instant observedAt,
        Instant expiresAt,
        Instant updatedAt) {
    PresenceRecord withVisibility(String visibility, int shareRadiusMeters, Instant updatedAt) {
        return new PresenceRecord(
                userId,
                displayName,
                avatarUrl,
                position,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                visibility,
                shareRadiusMeters,
                statusMessage,
                observedAt,
                expiresAt,
                updatedAt);
    }
}
