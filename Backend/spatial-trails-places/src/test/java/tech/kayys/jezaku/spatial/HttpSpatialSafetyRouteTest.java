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
    void buildsPolicyChangeFeedUriWithRevisionCursor() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal/"), 3);

        assertEquals(URI.create("http://safety.internal/safety/spatial/changes?afterRevision=12&limit=50"),
                safety.policyChangesUri(12, 50));
    }

    @Test
    void parsesOrderedPolicyChangePageAndPreservesCursorMetadata() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal"), 3);
        String payload = """
                {
                  "currentRevision": 14,
                  "afterRevision": 12,
                  "count": 2,
                  "events": [
                    {"policyRevision":13,"eventId":"spatial_policy_change_13","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-a","restrictionVersion":2,"action":"UPDATED",
                     "jurisdiction":"ID.32","outcome":"PROHIBITED","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:00:00Z"},
                    {"policyRevision":14,"eventId":"spatial_policy_change_14","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-b","restrictionVersion":1,"action":"CREATED",
                     "jurisdiction":"ID.32","outcome":"CAUTION","activities":["NAVIGATE","DISCOVER"],
                     "occurredAt":"2026-11-24T01:01:00Z"}
                  ]
                }
                """;

        var page = safety.parsePolicyChanges(payload, 12, 10);

        assertEquals(14, page.currentRevision());
        assertEquals(12, page.afterRevision());
        assertEquals(List.of(13L, 14L),
                page.events().stream().map(SpatialSafety.PolicyChangeEvent::policyRevision).toList());
        assertEquals(List.of("NAVIGATE", "DISCOVER"), page.events().get(1).activities());
    }

    @Test
    void acceptsEmptyPolicyChangePageOnlyWhenCursorIsAtHighWaterRevision() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal"), 3);
        String payload = """
                {"currentRevision":12,"afterRevision":12,"count":0,"events":[]}
                """;

        var page = safety.parsePolicyChanges(payload, 12, 10);

        assertEquals(12, page.currentRevision());
        assertTrue(page.events().isEmpty());
    }

    @Test
    void acceptsFullPageWithoutSkippingUnreturnedHighWaterEvents() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal"), 3);
        String payload = """
                {
                  "currentRevision":15,"afterRevision":12,"count":2,
                  "events":[
                    {"policyRevision":13,"eventId":"event-13","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-a","restrictionVersion":1,"action":"CREATED",
                     "jurisdiction":"ID.32","outcome":"PROHIBITED","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:00:00Z"},
                    {"policyRevision":14,"eventId":"event-14","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-b","restrictionVersion":1,"action":"UPDATED",
                     "jurisdiction":"ID.32","outcome":"CAUTION","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:01:00Z"}
                  ]
                }
                """;

        var page = safety.parsePolicyChanges(payload, 12, 2);

        assertEquals(15, page.currentRevision());
        assertEquals(14, page.events().getLast().policyRevision());
        // A consumer must continue from revision 14, not jump to currentRevision 15.
    }

    @Test
    void rejectsPolicyChangePagesWhenCountDoesNotMatchEvents() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal"), 3);
        String payload = """
                {"currentRevision":12,"afterRevision":12,"count":1,"events":[]}
                """;

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> safety.parsePolicyChanges(payload, 12, 10));

        assertEquals(503, failure.getResponse().getStatus());
    }
    @Test
    void rejectsPolicyChangePagesWithDuplicateOrOutOfOrderRevisions() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal"), 3);
        String payload = """
                {
                  "currentRevision": 14,
                  "afterRevision": 12,
                  "count": 2,
                  "events": [
                    {"policyRevision":14,"eventId":"event-14","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-a","restrictionVersion":1,"action":"CREATED",
                     "jurisdiction":"ID.32","outcome":"PROHIBITED","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:00:00Z"},
                    {"policyRevision":13,"eventId":"event-13","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-b","restrictionVersion":1,"action":"CREATED",
                     "jurisdiction":"ID.32","outcome":"PROHIBITED","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:01:00Z"}
                  ]
                }
                """;

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> safety.parsePolicyChanges(payload, 12, 10));

        assertEquals(503, failure.getResponse().getStatus());
    }

    @Test
    void rejectsPolicyChangePagesWithMissingRevision() {
        HttpSpatialSafety safety = new HttpSpatialSafety(true,
                Optional.of("http://safety.internal"), 3);
        String payload = """
                {
                  "currentRevision": 15,
                  "afterRevision": 12,
                  "count": 2,
                  "events": [
                    {"policyRevision":13,"eventId":"event-13","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-a","restrictionVersion":1,"action":"CREATED",
                     "jurisdiction":"ID.32","outcome":"PROHIBITED","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:00:00Z"},
                    {"policyRevision":15,"eventId":"event-15","eventType":"spatial.policy.changed",
                     "eventVersion":1,"restrictionId":"restriction-b","restrictionVersion":1,"action":"CREATED",
                     "jurisdiction":"ID.32","outcome":"PROHIBITED","activities":["NAVIGATE"],
                     "occurredAt":"2026-11-24T01:01:00Z"}
                  ]
                }
                """;

        WebApplicationException failure = assertThrows(WebApplicationException.class,
                () -> safety.parsePolicyChanges(payload, 12, 10));

        assertEquals(503, failure.getResponse().getStatus());
    }

    @Test
    void disabledLocalAdapterReturnsShortLivedExplicitAllowAssessment() {
        HttpSpatialSafety safety = new HttpSpatialSafety(false, Optional.empty(), 3);
        var route = new SpatialSafety.RouteCandidate("route-a", List.of(
                new GeoPoint(-6.9, 107.59, null),
                new GeoPoint(-6.901, 107.60, null)));

        var assessment = safety.evaluateRoutes(List.of(route), 20);

        assertEquals("local-unenforced", assessment.policySnapshotId());
        assertEquals(0L, assessment.policyRevision());
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
