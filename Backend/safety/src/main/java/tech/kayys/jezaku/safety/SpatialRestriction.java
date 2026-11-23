package tech.kayys.jezaku.safety;

import java.time.Instant;
import java.util.Objects;
import java.util.Set;

/**
 * Time-bounded, activity-scoped spatial restriction supplied by a trusted
 * policy source. This value object does not authenticate its issuer; trusted
 * ingestion and authorization are enforced at the service boundary.
 */
public record SpatialRestriction(
        String id,
        int version,
        String issuerType,
        String issuerId,
        String jurisdiction,
        String legalBasis,
        double centerLatitude,
        double centerLongitude,
        double radiusMeters,
        Outcome outcome,
        Set<Activity> activities,
        Instant effectiveFrom,
        Instant expiresAt,
        boolean active) {

    public SpatialRestriction {
        id = requireText(id, "id");
        if (version < 1) {
            throw new IllegalArgumentException("version must be positive");
        }
        issuerType = requireText(issuerType, "issuerType");
        issuerId = requireText(issuerId, "issuerId");
        jurisdiction = requireText(jurisdiction, "jurisdiction");
        legalBasis = legalBasis == null ? "" : legalBasis.trim();
        validateLatitude(centerLatitude);
        validateLongitude(centerLongitude);
        if (!Double.isFinite(radiusMeters) || radiusMeters <= 0) {
            throw new IllegalArgumentException("radiusMeters must be finite and positive");
        }
        Objects.requireNonNull(outcome, "outcome");
        activities = Set.copyOf(Objects.requireNonNull(activities, "activities"));
        if (activities.isEmpty()) {
            throw new IllegalArgumentException("activities must not be empty");
        }
        Objects.requireNonNull(effectiveFrom, "effectiveFrom");
        if (expiresAt != null && !expiresAt.isAfter(effectiveFrom)) {
            throw new IllegalArgumentException("expiresAt must be after effectiveFrom");
        }
    }

    public boolean appliesTo(Activity activity) {
        return activities.contains(Activity.ALL) || activities.contains(activity);
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        return value.trim();
    }

    private static void validateLatitude(double value) {
        if (!Double.isFinite(value) || value < -90 || value > 90) {
            throw new IllegalArgumentException("centerLatitude must be between -90 and 90");
        }
    }

    private static void validateLongitude(double value) {
        if (!Double.isFinite(value) || value < -180 || value > 180) {
            throw new IllegalArgumentException("centerLongitude must be between -180 and 180");
        }
    }

    public enum Outcome {
        ALLOWED,
        CAUTION,
        RESTRICTED,
        PROHIBITED,
        EMERGENCY_LOCKDOWN
    }

    public enum Activity {
        ALL,
        PUBLISH,
        DISCOVER,
        RENDER,
        NAVIGATE,
        REDEEM,
        INTERACT
    }
}
