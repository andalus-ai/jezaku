package tech.kayys.jezaku.safety;

import tech.kayys.jezaku.geo.GeoMath;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

/**
 * Pure evaluator for already-vetted circular spatial restrictions.
 *
 * <p>Authority authentication, persistence, polygon geometry, cache
 * invalidation, and endpoint enforcement belong to subsequent service slices.
 * This class only determines which supplied rules apply at a point in time.</p>
 */
public final class SpatialSafetyPolicy {
    private static final double BOUNDARY_TOLERANCE_METERS = 0.01;

    public Decision evaluate(Context context, List<SpatialRestriction> restrictions) {
        Objects.requireNonNull(context, "context");
        Objects.requireNonNull(restrictions, "restrictions");

        List<SpatialRestriction> matches = restrictions.stream()
                .filter(Objects::nonNull)
                .filter(SpatialRestriction::active)
                .filter(rule -> rule.appliesTo(context.activity()))
                .filter(rule -> isEffective(rule, context.evaluatedAt()))
                .filter(rule -> isInside(rule, context.latitude(), context.longitude()))
                .sorted(Comparator
                        .comparingInt((SpatialRestriction rule) -> severity(rule.outcome()))
                        .reversed()
                        .thenComparing(Comparator.comparingInt(SpatialRestriction::version).reversed())
                        .thenComparing(SpatialRestriction::id))
                .toList();

        if (matches.isEmpty()) {
            return new Decision(SpatialRestriction.Outcome.ALLOWED, List.of(),
                    "NO_MATCHING_RESTRICTION", null);
        }

        SpatialRestriction strongest = matches.getFirst();
        Instant validUntil = matches.stream()
                .map(SpatialRestriction::expiresAt)
                .filter(Objects::nonNull)
                .min(Comparator.naturalOrder())
                .orElse(null);

        return new Decision(strongest.outcome(),
                matches.stream().map(SpatialRestriction::id).toList(),
                reasonCode(strongest.outcome()), validUntil);
    }

    private boolean isEffective(SpatialRestriction rule, Instant at) {
        return !at.isBefore(rule.effectiveFrom())
                && (rule.expiresAt() == null || at.isBefore(rule.expiresAt()));
    }

    private boolean isInside(SpatialRestriction rule, double latitude, double longitude) {
        return GeoMath.distanceMeters(latitude, longitude,
                rule.centerLatitude(), rule.centerLongitude())
                <= rule.radiusMeters() + BOUNDARY_TOLERANCE_METERS;
    }

    private int severity(SpatialRestriction.Outcome outcome) {
        return switch (outcome) {
            case ALLOWED -> 0;
            case CAUTION -> 1;
            case RESTRICTED -> 2;
            case PROHIBITED -> 3;
            case EMERGENCY_LOCKDOWN -> 4;
        };
    }

    private String reasonCode(SpatialRestriction.Outcome outcome) {
        return switch (outcome) {
            case ALLOWED -> "EXPLICITLY_ALLOWED";
            case CAUTION -> "SPATIAL_CAUTION";
            case RESTRICTED -> "SPATIAL_RESTRICTED";
            case PROHIBITED -> "SPATIAL_PROHIBITED";
            case EMERGENCY_LOCKDOWN -> "EMERGENCY_LOCKDOWN";
        };
    }

    public record Context(
            double latitude,
            double longitude,
            SpatialRestriction.Activity activity,
            Instant evaluatedAt) {
        public Context {
            if (!Double.isFinite(latitude) || latitude < -90 || latitude > 90) {
                throw new IllegalArgumentException("latitude must be between -90 and 90");
            }
            if (!Double.isFinite(longitude) || longitude < -180 || longitude > 180) {
                throw new IllegalArgumentException("longitude must be between -180 and 180");
            }
            Objects.requireNonNull(activity, "activity");
            Objects.requireNonNull(evaluatedAt, "evaluatedAt");
            if (activity == SpatialRestriction.Activity.ALL) {
                throw new IllegalArgumentException("activity must be a concrete operation");
            }
        }
    }

    public record Decision(
            SpatialRestriction.Outcome outcome,
            List<String> restrictionIds,
            String reasonCode,
            Instant validUntil) {
        public Decision {
            Objects.requireNonNull(outcome, "outcome");
            restrictionIds = List.copyOf(restrictionIds);
            Objects.requireNonNull(reasonCode, "reasonCode");
        }

        public boolean permitsOperation() {
            return outcome == SpatialRestriction.Outcome.ALLOWED
                    || outcome == SpatialRestriction.Outcome.CAUTION;
        }
    }
}
