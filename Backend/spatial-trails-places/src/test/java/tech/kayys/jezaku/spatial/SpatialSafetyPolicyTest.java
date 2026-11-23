package tech.kayys.jezaku.spatial;

import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.spatial.SpatialDtos.AnchorCreateRequest;
import tech.kayys.jezaku.spatial.SpatialDtos.GeoPoint;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SpatialSafetyPolicyTest {
    @Test
    void nearbyAnchorsAndPlacesOmitDeniedCandidates() {
        SpatialService service = new SpatialService(denyAll());

        assertEquals(List.of(), service.nearbyAnchors(-6.91755, 107.61905, 250)
                .await().indefinitely());
        assertEquals(List.of(), service.nearbyPlaces(-6.91755, 107.61905, 250)
                .await().indefinitely());
    }

    @Test
    void placeDetailDoesNotRevealPlaceWhenPlaceDiscoveryIsDenied() {
        SpatialService service = new SpatialService(denyAll());

        assertThrows(NotFoundException.class,
                () -> service.placeDetail("place_bandung_campus").await().indefinitely());
    }

    @Test
    void anchorPublicationIsDeniedBeforePersistence() {
        SpatialService service = new SpatialService(denyAll());
        AnchorCreateRequest request = new AnchorCreateRequest(
                "test-owner",
                "Restricted anchor",
                "https://cdn.jezaku.local/restricted.jpg",
                new GeoPoint(-6.91755, 107.61905, 714.0),
                0.0,
                "public",
                "place_bandung_campus");

        assertThrows(WebApplicationException.class,
                () -> service.createAnchor(request).await().indefinitely());
    }

    @Test
    void cautionRemainsDiscoverable() {
        SpatialSafety caution = new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                return positions.stream().map(ignored -> "CAUTION").toList();
            }
        };
        SpatialService service = new SpatialService(caution);

        assertEquals(2, service.nearbyPlaces(-6.91755, 107.61905, 250)
                .await().indefinitely().size());
    }

    @Test
    void placeDetailDoesNotExposeDeniedAnchorsOrTheirAggregateCounts() {
        SpatialSafety renderDenied = new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                String outcome = "DISCOVER".equals(activity) ? "ALLOWED" : "PROHIBITED";
                return positions.stream().map(ignored -> outcome).toList();
            }
        };
        SpatialService service = new SpatialService(renderDenied);

        var detail = service.placeDetail("place_bandung_campus").await().indefinitely();

        assertEquals(List.of(), detail.anchors());
        assertEquals(0, detail.place().anchorCount());
        assertEquals(0, detail.place().trailCount());
    }

    @Test
    void incompleteDecisionBatchFailsClosed() {
        SpatialSafety incomplete = new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                return List.of();
            }
        };
        SpatialService service = new SpatialService(incomplete);

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> service.nearbyAnchors(-6.91755, 107.61905, 250).await().indefinitely());

        assertEquals(503, failure.getResponse().getStatus());
    }


    @Test
    void routeSafetyDefaultFailsClosedWhenNoAdapterIsConfigured() {
        SpatialSafety safety = new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                return List.of();
            }
        };
        var candidate = new SpatialSafety.RouteCandidate("candidate",
                List.of(new GeoPoint(-6.9, 107.59, null), new GeoPoint(-6.9, 107.60, null)));

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> safety.evaluateRoutes(List.of(candidate), 0));

        assertEquals(503, failure.getResponse().getStatus());
    }

    @Test
    void explicitLocalAllowAllProvidesOnlyShortLivedDevelopmentAssessment() {
        var candidate = new SpatialSafety.RouteCandidate("candidate",
                List.of(new GeoPoint(-6.9, 107.59, null), new GeoPoint(-6.9, 107.60, null)));

        var assessment = SpatialSafety.allowAll().evaluateRoutes(List.of(candidate), 0);

        assertEquals("local-unenforced", assessment.policySnapshotId());
        assertEquals(1, assessment.results().size());
        assertEquals("ALLOWED", assessment.results().get(0).outcome());
        assertTrue(assessment.results().get(0).validUntil().isAfter(assessment.evaluatedAt()));
    }

    private static SpatialSafety denyAll() {
        return new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
                throw new WebApplicationException("denied", 403);
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                return positions.stream().map(ignored -> "PROHIBITED").toList();
            }
        };
    }
}
