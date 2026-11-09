package tech.kayys.jezaku.safety;

import tech.kayys.jezaku.safety.SafetyDtos.GeoPoint;

import java.time.Instant;

record SafetyZoneRecord(
        String zoneId,
        String guardianId,
        String userId,
        String name,
        GeoPoint center,
        double radiusMeters,
        String zoneType,
        boolean active,
        Instant createdAt,
        Instant updatedAt) {
}
