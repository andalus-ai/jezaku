package tech.kayys.jezaku.safety;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class SafetyResourceTest {
    @Test
    void createsReportForModerationQueue() {
        String targetId = "memory_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_current",
                          "targetType": "memory",
                          "targetId": "%s",
                          "targetUserId": "user_rooftop",
                          "reason": "unsafe_location",
                          "details": "This memory exposes a private route.",
                          "evidenceMediaIds": ["media_seed_courtyard", "media_seed_courtyard"],
                          "position": {
                            "latitude": -6.890620,
                            "longitude": 107.610790,
                            "altitudeMeters": 742.0
                          }
                        }
                        """.formatted(targetId))
                .when()
                .post("/safety/reports")
                .then()
                .statusCode(201)
                .body("targetId", equalTo(targetId))
                .body("targetType", equalTo("memory"))
                .body("reason", equalTo("unsafe_location"))
                .body("status", equalTo("open"))
                .body("action", equalTo("none"))
                .body("evidenceMediaIds.size()", equalTo(1));
    }

    @Test
    void reviewsReportWithAction() {
        String reportId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_current",
                          "targetType": "media",
                          "targetId": "media_review_test",
                          "targetUserId": "user_rooftop",
                          "reason": "inappropriate_media",
                          "details": "Needs a human look."
                        }
                        """)
                .when()
                .post("/safety/reports")
                .then()
                .statusCode(201)
                .extract()
                .path("reportId");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reviewerId": "moderator_2",
                          "status": "resolved",
                          "action": "hide_content",
                          "notes": "Hidden pending creator appeal."
                        }
                        """)
                .when()
                .put("/safety/reports/{reportId}/review", reportId)
                .then()
                .statusCode(200)
                .body("reportId", equalTo(reportId))
                .body("status", equalTo("resolved"))
                .body("action", equalTo("hide_content"))
                .body("reviewerId", equalTo("moderator_2"));

        given()
                .when()
                .get("/safety/reports/{reportId}/reviews?reviewerId={reviewerId}", reportId, "moderator_2")
                .then()
                .statusCode(200)
                .body("reportId", equalTo(reportId))
                .body("count", equalTo(1))
                .body("events[0].reviewerId", equalTo("moderator_2"))
                .body("events[0].previousStatus", equalTo("open"))
                .body("events[0].nextStatus", equalTo("resolved"))
                .body("events[0].previousAction", equalTo("none"))
                .body("events[0].nextAction", equalTo("hide_content"))
                .body("events[0].notes", equalTo("Hidden pending creator appeal."));
    }

    @Test
    void listsOpenReportsOnly() {
        given()
                .when()
                .get("/safety/reports?status=open")
                .then()
                .statusCode(200)
                .body("status", equalTo("open"))
                .body("count", greaterThanOrEqualTo(1))
                .body("reports.reportId", hasItem("report_seed_media"))
                .body("reports.reportId", not(hasItem("report_seed_presence")));
    }

    @Test
    void filtersReportsForModerationQueue() {
        String targetUserId = "queue_user_" + UUID.randomUUID();
        String matchingTargetId = "message_" + UUID.randomUUID();
        String otherTargetId = "message_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_current",
                          "targetType": "message",
                          "targetId": "%s",
                          "targetUserId": "%s",
                          "reason": "underage_risk",
                          "details": "Suspicious contact pattern."
                        }
                        """.formatted(matchingTargetId, targetUserId))
                .when()
                .post("/safety/reports")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_current",
                          "targetType": "message",
                          "targetId": "%s",
                          "targetUserId": "queue_other",
                          "reason": "spam",
                          "details": "Different queue item."
                        }
                        """.formatted(otherTargetId))
                .when()
                .post("/safety/reports")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/safety/reports?status=open&targetType=message&reason=underage_risk&targetUserId={targetUserId}",
                        targetUserId)
                .then()
                .statusCode(200)
                .body("status", equalTo("open"))
                .body("count", equalTo(1))
                .body("reports.targetId", hasItem(matchingTargetId))
                .body("reports.targetId", not(hasItem(otherTargetId)));
    }

    @Test
    void summarizesReportQueueBuckets() {
        given()
                .when()
                .get("/safety/reports/summary")
                .then()
                .statusCode(200)
                .body("total", greaterThanOrEqualTo(2))
                .body("byStatus.key", hasItem("open"))
                .body("byStatus.key", hasItem("resolved"))
                .body("byTargetType.key", hasItem("media"))
                .body("byTargetType.key", hasItem("presence"))
                .body("byReason.key", hasItem("inappropriate_media"))
                .body("byReason.key", hasItem("unsafe_location"))
                .body("byAction.key", hasItem("none"))
                .body("byAction.key", hasItem("notify_guardian"));
    }

    @Test
    void createsGuardianZoneAndBlocksRestrictedLocation() {
        String userId = "zone_user_" + UUID.randomUUID();
        String zoneId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "guardianId": "guardian_2",
                          "userId": "%s",
                          "name": "Construction Roof",
                          "center": {
                            "latitude": -6.890580,
                            "longitude": 107.610970,
                            "altitudeMeters": 746.4
                          },
                          "radiusMeters": 40,
                          "zoneType": "restricted_area",
                          "active": true
                        }
                        """.formatted(userId))
                .when()
                .post("/safety/zones")
                .then()
                .statusCode(201)
                .body("userId", equalTo(userId))
                .body("zoneType", equalTo("restricted_area"))
                .body("active", equalTo(true))
                .extract()
                .path("zoneId");

        given()
                .when()
                .get("/safety/zones/users/{userId}", userId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("zones.zoneId", hasItem(zoneId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "position": {
                            "latitude": -6.890590,
                            "longitude": 107.610960
                          }
                        }
                        """.formatted(userId))
                .when()
                .post("/safety/zones/check")
                .then()
                .statusCode(200)
                .body("decision", equalTo("blocked"))
                .body("hitCount", equalTo(1))
                .body("hits.zoneId", hasItem(zoneId))
                .body("hits.action", hasItem("blocked"));
    }

    @Test
    void safeAreaOutsideNotifiesGuardian() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "teen_explorer",
                          "position": {
                            "latitude": -6.893100,
                            "longitude": 107.613300
                          }
                        }
                        """)
                .when()
                .post("/safety/zones/check")
                .then()
                .statusCode(200)
                .body("decision", equalTo("notify_guardian"))
                .body("hits.zoneId", hasItem("zone_seed_campus_safe"))
                .body("hits.action", hasItem("notify_guardian"));
    }

    @Test
    void invalidZoneCoordinateReturnsRequestIdError() {
        given()
                .header("X-Request-Id", "safety-bad-zone")
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "guardianId": "guardian_1",
                          "userId": "teen_explorer",
                          "name": "Bad Zone",
                          "center": {
                            "latitude": -99.0,
                            "longitude": 107.610790
                          },
                          "radiusMeters": 100,
                          "zoneType": "safe_area"
                        }
                        """)
                .when()
                .post("/safety/zones")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("safety-bad-zone"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/safety/zones"))
                .body("requestId", equalTo("safety-bad-zone"));
    }

    @Test
    void deletesZoneWithGuardianAuthorization() {
        String zoneId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "guardianId": "guardian_delete",
                          "userId": "child_delete",
                          "name": "Temporary Quiet Area",
                          "center": {
                            "latitude": -6.890620,
                            "longitude": 107.610790
                          },
                          "radiusMeters": 50,
                          "zoneType": "quiet_area",
                          "active": true
                        }
                        """)
                .when()
                .post("/safety/zones")
                .then()
                .statusCode(201)
                .extract()
                .path("zoneId");

        given()
                .when()
                .delete("/safety/zones/{zoneId}?guardianId=guardian_delete", zoneId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/safety/zones/users/child_delete")
                .then()
                .statusCode(200)
                .body("zones.zoneId", not(hasItem(zoneId)));
    }
}
