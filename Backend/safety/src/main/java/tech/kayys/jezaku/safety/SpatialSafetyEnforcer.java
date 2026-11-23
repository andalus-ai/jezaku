package tech.kayys.jezaku.safety;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.WebApplicationException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * Mandatory application boundary for operations affected by spatial safety.
 *
 * <p>Feature requests that evaluate multiple candidates should capture one
 * immutable snapshot and reuse it for every candidate. This avoids N+1 policy
 * reads and ensures every decision in a response uses the same evaluation
 * instant and policy set.</p>
 */
@ApplicationScoped
public class SpatialSafetyEnforcer {
    /**
     * Hard upper bound for one in-memory batch. Callers with larger result sets
     * must page/chunk them while retaining a request snapshot where appropriate.
     */
    public static final int MAX_BATCH_SIZE = 500;

    @Inject
    SpatialPolicyRepository repository;

    private final SpatialSafetyPolicy evaluator = new SpatialSafetyPolicy();

    /**
     * Reads active restrictions exactly once and freezes the result for reuse.
     * A repository failure is surfaced as 503; an empty authoritative result is
     * valid, but a null result is not.
     */
    public PolicySnapshot captureSnapshot() {
        Instant evaluatedAt = Instant.now();
        final List<SpatialRestriction> active;
        try {
            active = repository.findActiveRestrictions(evaluatedAt);
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
        try {
            return new PolicySnapshot(evaluatedAt, active);
        } catch (RuntimeException exception) {
            throw new WebApplicationException(
                    "Spatial safety policy returned an invalid snapshot; operation denied",
                    503);
        }
    }

    /** Evaluates a single point against a previously captured snapshot. */
    public SpatialSafetyPolicy.Decision evaluate(
            PolicySnapshot snapshot, double latitude, double longitude,
            SpatialRestriction.Activity activity) {
        Objects.requireNonNull(snapshot, "snapshot");
        SpatialSafetyPolicy.Context context = new SpatialSafetyPolicy.Context(
                latitude, longitude, activity, snapshot.evaluatedAt());
        return evaluator.evaluate(context, snapshot.restrictions());
    }

    /**
     * Evaluates a bounded, ordered collection of points against one snapshot.
     * The result at index i corresponds to target i. This method never performs
     * repository I/O.
     */
    public List<SpatialSafetyPolicy.Decision> evaluateBatch(
            PolicySnapshot snapshot, List<EvaluationTarget> targets) {
        Objects.requireNonNull(snapshot, "snapshot");
        if (targets == null) {
            throw new IllegalArgumentException("targets are required");
        }
        if (targets.size() > MAX_BATCH_SIZE) {
            throw new IllegalArgumentException(
                    "batch size must not exceed " + MAX_BATCH_SIZE);
        }
        List<EvaluationTarget> stableTargets = List.copyOf(targets);
        List<SpatialSafetyPolicy.Decision> decisions = new ArrayList<>(stableTargets.size());
        for (EvaluationTarget target : stableTargets) {
            decisions.add(evaluate(snapshot, target.latitude(), target.longitude(), target.activity()));
        }
        return List.copyOf(decisions);
    }

    /** Evaluates complete route geometry against the supplied request snapshot. */
    public SpatialSafetyPolicy.RouteDecision evaluateRoute(
            PolicySnapshot snapshot,
            List<SpatialRouteGeometry.Point> points,
            double corridorBufferMeters,
            SpatialRestriction.Activity activity) {
        Objects.requireNonNull(snapshot, "snapshot");
        return evaluator.evaluateRoute(points, corridorBufferMeters, activity,
                snapshot.evaluatedAt(), snapshot.restrictions());
    }

    /** Rejects route guidance unless every route segment is permitted or cautioned. */
    public SpatialSafetyPolicy.RouteDecision requireRoutePermitted(
            PolicySnapshot snapshot,
            List<SpatialRouteGeometry.Point> points,
            double corridorBufferMeters,
            SpatialRestriction.Activity activity) {
        SpatialSafetyPolicy.RouteDecision decision =
                evaluateRoute(snapshot, points, corridorBufferMeters, activity);
        if (!decision.permitsOperation()) {
            throw new WebApplicationException(
                    "Route denied by spatial safety policy: " + decision.reasonCode(), 403);
        }
        return decision;
    }

    /**
     * Convenience method for one-off checks. Multi-candidate request handlers
     * should use captureSnapshot() plus evaluate/evaluateBatch instead.
     */
    public SpatialSafetyPolicy.Decision evaluate(
            double latitude, double longitude, SpatialRestriction.Activity activity) {
        return evaluate(captureSnapshot(), latitude, longitude, activity);
    }

    /**
     * Enforcement entry point for a one-off feature operation. ALLOWED and
     * CAUTION pass; RESTRICTED, PROHIBITED, and EMERGENCY_LOCKDOWN are denied.
     */
    public SpatialSafetyPolicy.Decision requirePermitted(
            double latitude, double longitude, SpatialRestriction.Activity activity) {
        return requirePermitted(captureSnapshot(), latitude, longitude, activity);
    }

    /** Enforcement entry point when a caller already owns a request snapshot. */
    public SpatialSafetyPolicy.Decision requirePermitted(
            PolicySnapshot snapshot, double latitude, double longitude,
            SpatialRestriction.Activity activity) {
        SpatialSafetyPolicy.Decision decision = evaluate(snapshot, latitude, longitude, activity);
        if (!decision.permitsOperation()) {
            throw new WebApplicationException(
                    "Operation denied by spatial safety policy: " + decision.reasonCode(),
                    403);
        }
        return decision;
    }

    /** Immutable policy set and fixed evaluation instant for one request. */
    public record PolicySnapshot(Instant evaluatedAt, List<SpatialRestriction> restrictions) {
        public PolicySnapshot {
            Objects.requireNonNull(evaluatedAt, "evaluatedAt");
            restrictions = List.copyOf(Objects.requireNonNull(restrictions, "restrictions"));
        }
    }

    /** Candidate coordinate and operation to evaluate within a batch. */
    public record EvaluationTarget(
            double latitude, double longitude, SpatialRestriction.Activity activity) {
        public EvaluationTarget {
            Objects.requireNonNull(activity, "activity");
        }
    }
}
