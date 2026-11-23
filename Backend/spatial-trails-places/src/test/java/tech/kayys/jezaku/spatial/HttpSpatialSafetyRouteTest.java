package tech.kayys.jezaku.spatial;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.spatial.SpatialDtos.GeoPoint;

import java.net.URI;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HttpSpatialSafetyRouteTest {
    @Test
    void buildsCentralSafetyRouteEvaluationUri() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal/"), 3);

        assertEquals(URI.create("http://safety.internal/safety/spatial/evaluate/routes"),
                safety.routeEvaluationUri());
    }

    @Test
    void disabledLocalAdapterReturnsShortLivedExplicitAllowAssessment() {
        HttpSpatialSafety safety = new HttpSpatialSafety(false, Optional.empty(), 3);
        var route = new SpatialSafety.RouteCandidate("route-a", List.of(
                new GeoPoint(-6.9, 107.59, null),
                new GeoPoint(-6.901, 107.60, null)));

        var assessment = safety.evaluateRoutes(List.of(route), 20);

        assertEquals("local-unenforced", assessment.policySnapshotId());
        assertEquals("ALLOWED", assessment.results().getFirst().outcome());
        assertTrue(assessment.validUntil().isAfter(assessment.evaluatedAt()));
    }

    @Test
    void missingSafetyBaseUrlFailsClosed() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true, Optional.empty(), 3);
        var route = new SpatialSafety.RouteCandidate("route-a", List.of(
                new GeoPoint(-6.9, 107.59, null),
                new GeoPoint(-6.901, 107.60, null)));

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> safety.evaluateRoutes(List.of(route), 0));

        assertEquals(503, failure.getResponse().getStatus());
    }

    @Test
    void malformedRouteGeometryFailsClosedBeforeNetworkCall() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://127.0.0.1:1"), 1);
        var route = new SpatialSafety.RouteCandidate("route-a", List.of(
                new GeoPoint(-6.9, 107.59, null),
                new GeoPoint(91, 107.60, null)));

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> safety.evaluateRoutes(List.of(route), 0));

        assertEquals(503, failure.getResponse().getStatus());
    }
}
