package tech.kayys.jezaku.journeys;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class JourneyResourceTest {
    @Test
    void listsNearbyPublicJourneys() {
        given()
                .when()
                .get("/journeys?lat=-6.890620&lng=107.610790&radiusMeters=250&viewerId=user_current")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("count", greaterThan(0))
                .body("journeys.journeyId", hasItem("journey_seed_anchor_loop"))
                .body("journeys.journeyId", hasItem("journey_seed_photo_scout"))
                .body("journeys.journeyId", not(hasItem("journey_seed_private_guardian")))
                .body("journeys.journeyId", not(hasItem("journey_seed_far_view")))
                .body("journeys.distanceMeters", everyItemLessThanOrEqualTo(250.0f));
    }

    @Test
    void startsJourneySession() {
        String userId = "journey_user_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s"
                        }
                        """.formatted(userId))
                .when()
                .post("/journeys/{journeyId}/start", "journey_seed_anchor_loop")
                .then()
                .statusCode(201)
                .body("journeyId", equalTo("journey_seed_anchor_loop"))
                .body("userId", equalTo(userId))
                .body("status", equalTo("active"))
                .body("checkpointCount", equalTo(3))
                .body("completedCount", equalTo(0));
    }

    @Test
    void completesJourneyAndAwardsBadge() {
        String userId = "badge_user_" + UUID.randomUUID();
        String sessionId = startAnchorLoop(userId);

        complete(sessionId, "checkpoint_courtyard", userId, -6.890620, 107.610790)
                .body("status", equalTo("active"))
                .body("completedCount", equalTo(1));
        complete(sessionId, "checkpoint_rooftop", userId, -6.890580, 107.610970)
                .body("status", equalTo("active"))
                .body("completedCount", equalTo(2));
        complete(sessionId, "checkpoint_event_start", userId, -6.890620, 107.610790)
                .body("status", equalTo("completed"))
                .body("completedCount", equalTo(3))
                .body("awardedBadge.badgeId", equalTo("badge_anchor_loop"));

        given()
                .when()
                .get("/journeys/users/{userId}/badges", userId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("badges.badgeId", hasItem("badge_anchor_loop"));
    }

    @Test
    void preventsOutOfOrderCheckpointCompletion() {
        String userId = "order_user_" + UUID.randomUUID();
        String sessionId = startAnchorLoop(userId);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "position": {
                            "latitude": -6.890580,
                            "longitude": 107.610970
                          }
                        }
                        """.formatted(userId))
                .when()
                .post("/journeys/sessions/{sessionId}/checkpoints/{checkpointId}/complete", sessionId, "checkpoint_rooftop")
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"));
    }

    @Test
    void preventsCheckpointCompletionOutsideRadius() {
        String userId = "radius_user_" + UUID.randomUUID();
        String sessionId = startAnchorLoop(userId);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "position": {
                            "latitude": -6.893100,
                            "longitude": 107.613300
                          }
                        }
                        """.formatted(userId))
                .when()
                .post("/journeys/sessions/{sessionId}/checkpoints/{checkpointId}/complete", sessionId, "checkpoint_courtyard")
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"));
    }

    @Test
    void userJourneyListIncludesStartedSession() {
        String userId = "list_user_" + UUID.randomUUID();
        String sessionId = startAnchorLoop(userId);

        given()
                .when()
                .get("/journeys/users/{userId}", userId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("journeys.sessionId", hasItem(sessionId))
                .body("journeys.status", hasItem("active"));
    }

    @Test
    void listRequiresCoordinatesWithRequestId() {
        given()
                .header("X-Request-Id", "journeys-missing-coordinates")
                .when()
                .get("/journeys")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("journeys-missing-coordinates"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/journeys"))
                .body("requestId", equalTo("journeys-missing-coordinates"));
    }

    private String startAnchorLoop(String userId) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s"
                        }
                        """.formatted(userId))
                .when()
                .post("/journeys/{journeyId}/start", "journey_seed_anchor_loop")
                .then()
                .statusCode(201)
                .extract()
                .path("sessionId");
    }

    private io.restassured.response.ValidatableResponse complete(
            String sessionId,
            String checkpointId,
            String userId,
            double lat,
            double lng) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "position": {
                            "latitude": %s,
                            "longitude": %s
                          }
                        }
                        """.formatted(userId, lat, lng))
                .when()
                .post("/journeys/sessions/{sessionId}/checkpoints/{checkpointId}/complete", sessionId, checkpointId)
                .then()
                .statusCode(200);
    }

    private org.hamcrest.Matcher<Iterable<? extends Float>> everyItemLessThanOrEqualTo(float value) {
        return org.hamcrest.Matchers.everyItem(lessThanOrEqualTo(value));
    }
}
