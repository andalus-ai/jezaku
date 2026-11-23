package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

public record StorePlacement(
        double latitude,
        double longitude,
        double horizontalAccuracyMeters,
        String source,
        PlacementStatus status,
        String verifiedBy,
        Instant verifiedAt,
        long revision) {

    public StorePlacement {
        if (!Double.isFinite(latitude) || latitude < -90 || latitude > 90) {
            throw new IllegalArgumentException("latitude must be finite and within [-90, 90]");
        }
        if (!Double.isFinite(longitude) || longitude < -180 || longitude > 180) {
            throw new IllegalArgumentException("longitude must be finite and within [-180, 180]");
        }
        if (!Double.isFinite(horizontalAccuracyMeters) || horizontalAccuracyMeters <= 0) {
            throw new IllegalArgumentException("horizontalAccuracyMeters must be finite and positive");
        }
        if (source == null || source.isBlank()) {
            throw new IllegalArgumentException("source must not be blank");
        }
        Objects.requireNonNull(status, "status");
        if (revision < 0) {
            throw new IllegalArgumentException("revision must not be negative");
        }
        if (status == PlacementStatus.VERIFIED) {
            if (verifiedBy == null || verifiedBy.isBlank() || verifiedAt == null) {
                throw new IllegalArgumentException("Verified placement requires verifier and timestamp");
            }
        }
    }

    public StorePlacement verify(String actorId, Instant at) {
        if (status != PlacementStatus.PROPOSED) {
            throw new IllegalStateException("Only proposed placements can be verified");
        }
        if (actorId == null || actorId.isBlank()) {
            throw new IllegalArgumentException("actorId must not be blank");
        }
        Objects.requireNonNull(at, "at");
        return new StorePlacement(latitude, longitude, horizontalAccuracyMeters, source,
                PlacementStatus.VERIFIED, actorId.trim(), at, revision + 1);
    }

    public StorePlacement revoke() {
        if (status != PlacementStatus.VERIFIED) {
            throw new IllegalStateException("Only verified placements can be revoked");
        }
        return new StorePlacement(latitude, longitude, horizontalAccuracyMeters, source,
                PlacementStatus.REVOKED, null, null, revision + 1);
    }

    public boolean isPubliclyUsable() {
        return status == PlacementStatus.VERIFIED;
    }
}
