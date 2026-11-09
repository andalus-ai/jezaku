package tech.kayys.jezaku.discovery;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class DiscoveryResourceTest {
    @Test
    void nearbyReturnsRankedDiscoveryItemsAroundViewer() {
        given()
                .when()
                .get("/discovery/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100&viewerId=user_current")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("radiusMeters", equalTo(100.0f))
                .body("count", greaterThan(0))
                .body("items.targetId", hasItem("memory_seed_courtyard"))
                .body("items.targetId", hasItem("event_seed_campus_walk"))
                .body("items.targetId", not(hasItem("media_seed_pending")))
                .body("items.targetId", not(hasItem("place_far_view")))
                .body("items.distanceMeters", everyItem(lessThanOrEqualTo(100.0f)))
                .body("items.score", everyItem(greaterThan(0.0f)));
    }

    @Test
    void nearbySupportsTypeFilter() {
        given()
                .when()
                .get("/discovery/nearby?lat=-6.890620&lng=107.610790&radiusMeters=200&type=event")
                .then()
                .statusCode(200)
                .body("items.targetType", everyItem(equalTo("event")))
                .body("items.targetId", hasItem("event_seed_campus_walk"))
                .body("items.targetId", hasItem("event_seed_rooftop_meet"));
    }

    @Test
    void nearbyRequiresCoordinatesWithRequestId() {
        given()
                .header("X-Request-Id", "discovery-missing-coordinates")
                .when()
                .get("/discovery/nearby")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("discovery-missing-coordinates"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/discovery/nearby"))
                .body("requestId", equalTo("discovery-missing-coordinates"));
    }

    @Test
    void searchFindsCompassItemsNearViewer() {
        given()
                .when()
                .get("/discovery/search?q=compass&lat=-6.890620&lng=107.610790&radiusMeters=200")
                .then()
                .statusCode(200)
                .body("query", equalTo("compass"))
                .body("count", greaterThanOrEqualTo(2))
                .body("items.targetId", hasItem("event_seed_rooftop_meet"))
                .body("items.targetId", hasItem("place_rooftop_lane"))
                .body("items.targetId", not(hasItem("media_seed_pending")));
    }

    @Test
    void trendingExcludesUndiscoverableModerationItems() {
        given()
                .when()
                .get("/discovery/trending?lat=-6.890620&lng=107.610790&radiusMeters=500")
                .then()
                .statusCode(200)
                .body("count", greaterThan(0))
                .body("items.targetId", hasItem("event_seed_campus_walk"))
                .body("items.targetId", not(hasItem("media_seed_pending")));
    }

    @Test
    void feedbackCanHideItemFromForYou() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_current",
                          "targetType": "memory",
                          "targetId": "memory_seed_rooftop",
                          "action": "hidden"
                        }
                        """)
                .when()
                .post("/discovery/feedback")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("action", equalTo("hidden"));

        given()
                .when()
                .get("/discovery/users/user_current/for-you?lat=-6.890620&lng=107.610790&radiusMeters=500")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("items.targetId", not(hasItem("memory_seed_rooftop")));
    }

    @Test
    void feedbackCanBoostSavedItemForUser() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_current",
                          "targetType": "place",
                          "targetId": "place_rooftop_lane",
                          "action": "saved"
                        }
                        """)
                .when()
                .post("/discovery/feedback")
                .then()
                .statusCode(200)
                .body("action", equalTo("saved"));

        given()
                .when()
                .get("/discovery/users/user_current/for-you?lat=-6.890620&lng=107.610790&radiusMeters=500")
                .then()
                .statusCode(200)
                .body("items.find { it.targetId == 'place_rooftop_lane' }.score", greaterThan(100.0f));
    }
}
