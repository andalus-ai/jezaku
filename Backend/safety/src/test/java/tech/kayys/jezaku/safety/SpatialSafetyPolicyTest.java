package tech.kayys.jezaku.safety;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SpatialSafetyPolicyTest {
    private static final Instant NOW = Instant.parse("2026-11-23T10:00:00Z");
    private static final SpatialSafetyPolicy POLICY = new SpatialSafetyPolicy();

    @Test
    void prohibitsNavigationInsideActiveRestriction() {
        SpatialRestriction restriction = restriction("road-closure",
                SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.NAVIGATE),
                NOW.minusSeconds(60), NOW.plusSeconds(600), true);

        SpatialSafetyPolicy.Decision decision = POLICY.evaluate(
                context(SpatialRestriction.Activity.NAVIGATE), List.of(restriction));

        assertEquals(SpatialRestriction.Outcome.PROHIBITED, decision.outcome());
        assertEquals(List.of("road-closure"), decision.restrictionIds());
        assertFalse(decision.permitsOperation());
    }

    @Test
    void ignoresRestrictionOutsideItsRadius() {
        SpatialRestriction restriction = restriction("small-zone",
                SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.ALL),
                NOW.minusSeconds(60), null, true);

        SpatialSafetyPolicy.Decision decision = POLICY.evaluate(
                new SpatialSafetyPolicy.Context(-6.9000, 107.6100,
                        SpatialRestriction.Activity.NAVIGATE, NOW), List.of(restriction));

        assertEquals(SpatialRestriction.Outcome.ALLOWED, decision.outcome());
        assertTrue(decision.permitsOperation());
    }

    @Test
    void ignoresExpiredInactiveAndNonApplicableRestrictions() {
        List<SpatialRestriction> restrictions = List.of(
                restriction("expired", SpatialRestriction.Outcome.PROHIBITED,
                        Set.of(SpatialRestriction.Activity.ALL), NOW.minusSeconds(600), NOW, true),
                restriction("inactive", SpatialRestriction.Outcome.PROHIBITED,
                        Set.of(SpatialRestriction.Activity.ALL), NOW.minusSeconds(60), null, false),
                restriction("wrong-activity", SpatialRestriction.Outcome.PROHIBITED,
                        Set.of(SpatialRestriction.Activity.PUBLISH), NOW.minusSeconds(60), null, true));

        SpatialSafetyPolicy.Decision decision = POLICY.evaluate(
                context(SpatialRestriction.Activity.NAVIGATE), restrictions);

        assertEquals(SpatialRestriction.Outcome.ALLOWED, decision.outcome());
        assertTrue(decision.restrictionIds().isEmpty());
    }

    @Test
    void emergencyLockdownWinsOverOverlappingRestrictions() {
        SpatialRestriction prohibited = restriction("ordinary-ban",
                SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.ALL),
                NOW.minusSeconds(60), NOW.plusSeconds(600), true);
        SpatialRestriction emergency = restriction("emergency",
                SpatialRestriction.Outcome.EMERGENCY_LOCKDOWN,
                Set.of(SpatialRestriction.Activity.ALL),
                NOW.minusSeconds(60), NOW.plusSeconds(120), true);

        SpatialSafetyPolicy.Decision decision = POLICY.evaluate(
                context(SpatialRestriction.Activity.RENDER), List.of(prohibited, emergency));

        assertEquals(SpatialRestriction.Outcome.EMERGENCY_LOCKDOWN, decision.outcome());
        assertEquals("emergency", decision.restrictionIds().getFirst());
        assertEquals(NOW.plusSeconds(120), decision.validUntil());
    }

    @Test
    void cautionIsPermittedButExplicit() {
        SpatialRestriction caution = restriction("construction-nearby",
                SpatialRestriction.Outcome.CAUTION,
                Set.of(SpatialRestriction.Activity.ALL),
                NOW.minusSeconds(60), null, true);

        SpatialSafetyPolicy.Decision decision = POLICY.evaluate(
                context(SpatialRestriction.Activity.DISCOVER), List.of(caution));

        assertEquals(SpatialRestriction.Outcome.CAUTION, decision.outcome());
        assertTrue(decision.permitsOperation());
        assertEquals("SPATIAL_CAUTION", decision.reasonCode());
    }

    @Test
    void validatesRestrictionAndContextCoordinates() {
        assertThrows(IllegalArgumentException.class, () -> restriction("invalid",
                SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.ALL), NOW, null, true,
                91, 0));

        assertThrows(IllegalArgumentException.class, () -> new SpatialSafetyPolicy.Context(
                0, 0, SpatialRestriction.Activity.ALL, NOW));
    }

    @Test
    void blocksRouteWhenRestrictionIsBetweenClearEndpoints() {
        SpatialRestriction restriction = new SpatialRestriction(
                "mid-route-closure", 1, "AUTHORITY", "issuer-1", "test-jurisdiction", "",
                0.0, 0.005, 150, SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.NAVIGATE),
                NOW.minusSeconds(60), NOW.plusSeconds(600), true);

        var decision = POLICY.evaluateRoute(
                List.of(new SpatialRouteGeometry.Point(0.0, 0.0),
                        new SpatialRouteGeometry.Point(0.0, 0.01)),
                0, SpatialRestriction.Activity.NAVIGATE, NOW, List.of(restriction));

        assertEquals(SpatialRestriction.Outcome.PROHIBITED, decision.outcome());
        assertEquals(List.of("mid-route-closure"), decision.restrictionIds());
        assertEquals(List.of(0), decision.affectedSegmentIndices());
        assertFalse(decision.permitsOperation());
    }

    @Test
    void routeCorridorBufferExpandsRestrictionIntersection() {
        SpatialRestriction restriction = new SpatialRestriction(
                "near-route", 1, "AUTHORITY", "issuer-1", "test-jurisdiction", "",
                0.0018, 0.005, 100, SpatialRestriction.Outcome.CAUTION,
                Set.of(SpatialRestriction.Activity.NAVIGATE),
                NOW.minusSeconds(60), null, true);
        List<SpatialRouteGeometry.Point> route = List.of(
                new SpatialRouteGeometry.Point(0.0, 0.0),
                new SpatialRouteGeometry.Point(0.0, 0.01));

        var withoutBuffer = POLICY.evaluateRoute(route, 0,
                SpatialRestriction.Activity.NAVIGATE, NOW, List.of(restriction));
        var withBuffer = POLICY.evaluateRoute(route, 120,
                SpatialRestriction.Activity.NAVIGATE, NOW, List.of(restriction));

        assertEquals(SpatialRestriction.Outcome.ALLOWED, withoutBuffer.outcome());
        assertEquals(SpatialRestriction.Outcome.CAUTION, withBuffer.outcome());
        assertTrue(withBuffer.permitsOperation());
    }

    @Test
    void routeIntersectionHandlesAntimeridianCrossing() {
        SpatialRestriction restriction = new SpatialRestriction(
                "dateline-closure", 1, "AUTHORITY", "issuer-1", "test-jurisdiction", "",
                0.0, 180.0, 2_000, SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.NAVIGATE),
                NOW.minusSeconds(60), null, true);

        var decision = POLICY.evaluateRoute(
                List.of(new SpatialRouteGeometry.Point(0.0, 179.9),
                        new SpatialRouteGeometry.Point(0.0, -179.9)),
                0, SpatialRestriction.Activity.NAVIGATE, NOW, List.of(restriction));

        assertEquals(SpatialRestriction.Outcome.PROHIBITED, decision.outcome());
        assertEquals(List.of(0), decision.affectedSegmentIndices());
    }

    @Test
    void routeEvaluationHonorsActivityAndTimeWindows() {
        SpatialRestriction restriction = new SpatialRestriction(
                "publish-only", 1, "AUTHORITY", "issuer-1", "test-jurisdiction", "",
                0.0, 0.005, 500, SpatialRestriction.Outcome.PROHIBITED,
                Set.of(SpatialRestriction.Activity.PUBLISH),
                NOW.plusSeconds(60), NOW.plusSeconds(600), true);

        var decision = POLICY.evaluateRoute(
                List.of(new SpatialRouteGeometry.Point(0.0, 0.0),
                        new SpatialRouteGeometry.Point(0.0, 0.01)),
                0, SpatialRestriction.Activity.NAVIGATE, NOW, List.of(restriction));

        assertEquals(SpatialRestriction.Outcome.ALLOWED, decision.outcome());
    }

    @Test
    void rejectsMalformedOrUnboundedRouteGeometry() {
        assertThrows(IllegalArgumentException.class, () -> SpatialRouteGeometry.validate(
                List.of(new SpatialRouteGeometry.Point(0, 0)), 0));
        assertThrows(IllegalArgumentException.class, () -> SpatialRouteGeometry.validate(
                List.of(new SpatialRouteGeometry.Point(0, 0),
                        new SpatialRouteGeometry.Point(0, 0)), 0));
        assertThrows(IllegalArgumentException.class, () -> SpatialRouteGeometry.validate(
                List.of(new SpatialRouteGeometry.Point(0, 0),
                        new SpatialRouteGeometry.Point(0, 2)), 0));
        assertThrows(IllegalArgumentException.class, () -> SpatialRouteGeometry.validate(
                List.of(new SpatialRouteGeometry.Point(91, 0),
                        new SpatialRouteGeometry.Point(0, 1)), 0));
    }

    private SpatialSafetyPolicy.Context context(SpatialRestriction.Activity activity) {
        return new SpatialSafetyPolicy.Context(-6.890620, 107.610790, activity, NOW);
    }

    private SpatialRestriction restriction(String id, SpatialRestriction.Outcome outcome,
            Set<SpatialRestriction.Activity> activities, Instant effectiveFrom,
            Instant expiresAt, boolean active) {
        return restriction(id, outcome, activities, effectiveFrom, expiresAt, active,
                -6.890620, 107.610790);
    }

    private SpatialRestriction restriction(String id, SpatialRestriction.Outcome outcome,
            Set<SpatialRestriction.Activity> activities, Instant effectiveFrom,
            Instant expiresAt, boolean active, double latitude, double longitude) {
        return new SpatialRestriction(id, 1, "AUTHORITY", "issuer-1",
                "test-jurisdiction", "test legal basis", latitude, longitude, 100,
                outcome, activities, effectiveFrom, expiresAt, active);
    }
}
