package tech.kayys.jezaku.spatial;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.CoreMatchers.hasItem;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasSize;

@QuarkusTest
class SpatialTrailPlaceResourceTest {
    @Test
    void nearbyAnchorsReturnDistanceSortedSpatialMemories() {
        given()
                .queryParam("lat", -6.91755)
                .queryParam("lng", 107.61905)
                .queryParam("radiusMeters", 100)
                .when()
                .get("/spatial/anchors/nearby")
                .then()
                .statusCode(200)
                .body("size()", greaterThanOrEqualTo(2))
                .body("[0].id", equalTo("anchor_courtyard"))
                .body("[0].distanceMeters", equalTo(0.0f))
                .body("id", hasItem("anchor_rooftop"));
    }

    @Test
    void anchorsCanBeCreatedForFuturePostgisPersistence() {
        given()
                .contentType("application/json")
                .body("""
                        {
                          "ownerId": "demo-user",
                          "title": "Library window",
                          "mediaUrl": "https://cdn.jezaku.local/library.jpg",
                          "position": {
                            "latitude": -6.91762,
                            "longitude": 107.61912,
                            "altitudeMeters": 716.0
                          },
                          "headingDegrees": 451.0,
                          "visibility": "friends",
                          "placeId": "place_bandung_campus"
                        }
                        """)
                .when()
                .post("/spatial/anchors")
                .then()
                .statusCode(201)
                .body("id", notNullValue())
                .body("title", equalTo("Library window"))
                .body("headingDegrees", equalTo(91.0f))
                .body("visibility", equalTo("friends"))
                .body("placeId", equalTo("place_bandung_campus"));
    }

    @Test
    void trailHistoryCanRecordSaveUnsaveAndClearCompletedRoutes() {
        final var userId = "test-user-" + UUID.randomUUID();
        final var trailId = given()
                .contentType("application/json")
                .body("""
                        {
                          "userId": "%s",
                          "title": "Capture perimeter trail",
                          "source": "camera",
                          "memoryIds": [
                            "anchor_courtyard",
                            "anchor_rooftop",
                            "anchor_private"
                          ],
                          "startedAt": "2026-05-29T09:00:00Z",
                          "finishedAt": "2026-05-29T09:08:00Z"
                        }
                        """.formatted(userId))
                .when()
                .post("/trails/completions")
                .then()
                .statusCode(201)
                .body("sourceLabel", equalTo("Camera"))
                .body("stopCount", equalTo(3))
                .body("elapsedSeconds", equalTo(480))
                .extract()
                .path("id")
                .toString();

        given()
                .when()
                .get("/trails/history/{userId}", userId)
                .then()
                .statusCode(200)
                .body("summary.completedTrailCount", equalTo(1))
                .body("summary.reachedStopCount", equalTo(3))
                .body("summary.totalElapsedSeconds", equalTo(480))
                .body("summary.sources[0].source", equalTo("camera"))
                .body("summary.sources[0].completedTrailCount", equalTo(1))
                .body("trails", hasSize(1))
                .body("trails[0].saved", equalTo(false));

        given()
                .contentType("application/json")
                .body("""
                        {
                          "userId": "%s",
                          "trailId": "%s"
                        }
                        """.formatted(userId, trailId))
                .when()
                .post("/trails/saved")
                .then()
                .statusCode(200)
                .body("id", equalTo(trailId))
                .body("saved", equalTo(true));

        given()
                .when()
                .get("/trails/saved/{userId}", userId)
                .then()
                .statusCode(200)
                .body("id", hasItem(trailId));

        given()
                .when()
                .delete("/trails/saved/{userId}/{trailId}", userId, trailId)
                .then()
                .statusCode(204);

        given()
                .when()
                .delete("/trails/history/{userId}", userId)
                .then()
                .statusCode(200)
                .body("summary.completedTrailCount", equalTo(0))
                .body("trails", hasSize(0));
    }

    @Test
    void trailCompletionRequiresAtLeastTwoStops() {
        given()
                .contentType("application/json")
                .header("X-Request-Id", "spatial-bad-trail")
                .body("""
                        {
                          "userId": "bad-route-user",
                          "title": "Single stop",
                          "source": "camera",
                          "memoryIds": ["anchor_courtyard"],
                          "startedAt": "2026-05-29T09:00:00Z",
                          "finishedAt": "2026-05-29T09:01:00Z"
                        }
                        """)
                .when()
                .post("/trails/completions")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("spatial-bad-trail"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/trails/completions"))
                .body("requestId", equalTo("spatial-bad-trail"));
    }

    @Test
    void nearbyPlacesExposeAnchorsAndTrailCounts() {
        given()
                .queryParam("lat", -6.91755)
                .queryParam("lng", 107.61905)
                .queryParam("radiusMeters", 250)
                .when()
                .get("/places/nearby")
                .then()
                .statusCode(200)
                .body("id", hasItem("place_bandung_campus"))
                .body("find { it.id == 'place_bandung_campus' }.anchorCount",
                        greaterThanOrEqualTo(2));

        given()
                .when()
                .get("/places/{placeId}", "place_bandung_campus")
                .then()
                .statusCode(200)
                .body("place.id", equalTo("place_bandung_campus"))
                .body("anchors.id", hasItem("anchor_courtyard"));
    }
}
