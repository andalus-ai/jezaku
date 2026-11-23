package tech.kayys.jezaku.safety;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.WebApplicationException;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

/**
 * Mandatory application boundary for operations affected by spatial safety.
 *
 * <p>Call {@link #requirePermitted(double, double, SpatialRestriction.Activity)}
 * before performing a publish, discovery, render, navigation, redemption, or
 * interaction side effect. This class deliberately has no permissive fallback:
 * if policy storage cannot be read, the operation is rejected.</p>
 */
@ApplicationScoped
public class SpatialSafetyEnforcer {
    @Inject
    SpatialPolicyRepository repository;

    private final SpatialSafetyPolicy evaluator = new SpatialSafetyPolicy();

    /**
     * Evaluates the current persisted policy snapshot. A repository failure is
     * surfaced as 503 so callers cannot mistake missing policy data for ALLOWED.
     */
    public SpatialSafetyPolicy.Decision evaluate(
            double latitude, double longitude, SpatialRestriction.Activity activity) {
        SpatialSafetyPolicy.Context context = new SpatialSafetyPolicy.Context(
                latitude, longitude, activity, Instant.now());
        final List<SpatialRestriction> active;
        try {
            active = repository.findActiveRestrictions(context.evaluatedAt());
        } catch (RuntimeException exception) {
            throw new WebApplicationException(
                    "Spatial safety policy is temporarily unavailable; operation denied",
                    503);
        }
        if (active == null) {
            throw new WebApplicationException(
                    "Spatial safety policy returned no authoritative result; operation denied",
                    503);
        }
        return evaluator.evaluate(context, active);
    }

    /**
     * Enforcement entry point for feature services. ALLOWED and CAUTION pass;
     * RESTRICTED, PROHIBITED, and EMERGENCY_LOCKDOWN are denied.
     */
    public SpatialSafetyPolicy.Decision requirePermitted(
            double latitude, double longitude, SpatialRestriction.Activity activity) {
        SpatialSafetyPolicy.Decision decision = evaluate(latitude, longitude, activity);
        if (!decision.permitsOperation()) {
            throw new WebApplicationException(
                    "Operation denied by spatial safety policy: " + decision.reasonCode(),
                    403);
        }
        return decision;
    }
}
