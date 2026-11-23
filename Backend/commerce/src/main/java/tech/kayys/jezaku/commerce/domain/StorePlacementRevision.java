package tech.kayys.jezaku.commerce.domain;

import java.time.Instant;
import java.util.Objects;

/** Immutable snapshot of one store-placement revision and its review provenance. */
public record StorePlacementRevision(
        String storeId,
        long revision,
        double latitude,
        double longitude,
        double horizontalAccuracyMeters,
        String source,
        PlacementStatus status,
        String verifiedBy,
        Instant verifiedAt,
        String action,
        String recordedBy,
        Instant recordedAt,
        String reasonCode) {

    public StorePlacementRevision {
        if (storeId == null || storeId.isBlank()) throw new IllegalArgumentException("storeId must not be blank");
        if (revision < 0) throw new IllegalArgumentException("revision must not be negative");
        if (!Double.isFinite(latitude) || latitude < -90 || latitude > 90) throw new IllegalArgumentException("invalid latitude");
        if (!Double.isFinite(longitude) || longitude < -180 || longitude > 180) throw new IllegalArgumentException("invalid longitude");
        if (!Double.isFinite(horizontalAccuracyMeters) || horizontalAccuracyMeters <= 0) throw new IllegalArgumentException("invalid horizontal accuracy");
        if (source == null || source.isBlank()) throw new IllegalArgumentException("source must not be blank");
        Objects.requireNonNull(status, "status");
        if (status == PlacementStatus.VERIFIED) {
            if (verifiedBy == null || verifiedBy.isBlank() || verifiedAt == null) {
                throw new IllegalArgumentException("verified revision requires verifier and timestamp");
            }
        } else if (verifiedBy != null || verifiedAt != null) {
            throw new IllegalArgumentException("non-verified revision cannot contain verification metadata");
        }
        if (action == null || action.isBlank()) throw new IllegalArgumentException("action must not be blank");
        if (recordedBy == null || recordedBy.isBlank()) throw new IllegalArgumentException("recordedBy must not be blank");
        Objects.requireNonNull(recordedAt, "recordedAt");
    }
}
