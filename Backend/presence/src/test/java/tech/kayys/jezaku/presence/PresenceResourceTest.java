package tech.kayys.jezaku.presence;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasItems;
import static org.hamcrest.Matchers.lessThan;
import static org.hamcrest.Matchers.lessThanOrEqualTo;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;

@QuarkusTest
class PresenceResourceTest {
    @Test
    void returnsPresenceOpsHealth() {
        given()
                .when()
                .get("/presence/ops/health")
                .then()
                .statusCode(200)
                .body("status", equalTo("healthy"))
                .body("score", equalTo(100))
                .body("totalPresenceCount", greaterThanOrEqualTo(1))
                .body("activePresenceCount", greaterThanOrEqualTo(1))
                .body("audienceAccess.requestedSource", equalTo("local"))
                .body("audienceAccess.effectiveSource", equalTo("local"))
                .body("audienceAccess.health", equalTo("healthy"))
                .body("audienceAccess.ready", equalTo(true))
                .body("audienceAccess.issues.size()", equalTo(0))
                .body("generatedAt", notNullValue());
    }

    @Test
    void checksInWithCameraTelemetry() {
        String userId = "presence_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Camera Walker",
                          "avatarUrl": "https://cdn.jezaku.local/avatars/camera.jpg",
                          "position": {
                            "latitude": -6.890610,
                            "longitude": 107.610800,
                            "altitudeMeters": 743.2
                          },
                          "headingDegrees": 721,
                          "compassDegrees": -12,
                          "speedMetersPerSecond": 1.27,
                          "visibility": "public",
                          "shareRadiusMeters": 120,
                          "statusMessage": "Scanning the path"
                        }
                        """.formatted(userId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201)
                .body("userId", equalTo(userId))
                .body("position.altitudeMeters", equalTo(743.2f))
                .body("headingDegrees", equalTo(1.0f))
                .body("compassDegrees", equalTo(348.0f))
                .body("speedMetersPerSecond", equalTo(1.27f))
                .body("shareRadiusMeters", equalTo(120))
                .body("online", equalTo(true));
    }

    @Test
    void nearbyReturnsFreshPublicPresenceDots() {
        given()
                .when()
                .get("/presence/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100&viewerId=user_current")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("center.latitude", equalTo(-6.89062f))
                .body("center.longitude", equalTo(107.61079f))
                .body("orientationDegrees", equalTo(0.0f))
                .body("radiusMeters", equalTo(100.0f))
                .body("summary.count", greaterThanOrEqualTo(1))
                .body("summary.freshCount", greaterThanOrEqualTo(1))
                .body("summary.perimeterCount", equalTo(0))
                .body("visibility.mode", equalTo("local_public_only"))
                .body("visibility.audienceSource", equalTo("local"))
                .body("visibility.candidateCount", greaterThanOrEqualTo(1))
                .body("visibility.hiddenCandidateCount", greaterThanOrEqualTo(1))
                .body("visibility.hiddenReasons.reason", hasItem("self_excluded"))
                .body("users.userId", hasItem("user_rooftop"))
                .body("users.userId", not(hasItem("user_current")))
                .body("users.userId", not(hasItem("user_private")))
                .body("users.userId", not(hasItem("user_far")))
                .body("users.userId", not(hasItem("user_stale")))
                .body("users.find { it.userId == 'user_rooftop' }.visibility", equalTo("public"))
                .body("users.find { it.userId == 'user_rooftop' }.shareRadiusMeters", equalTo(100))
                .body("users.find { it.userId == 'user_rooftop' }.statusMessage",
                        equalTo("Near the virtual wall"))
                .body("users.find { it.userId == 'user_rooftop' }.distanceRatio",
                        allOf(greaterThan(0.0f), lessThan(0.25f)))
                .body("users.find { it.userId == 'user_rooftop' }.distanceBucket", equalTo("near"))
                .body("users.find { it.userId == 'user_rooftop' }.perimeter", equalTo(false))
                .body("users.find { it.userId == 'user_rooftop' }.relativeBearingDegrees",
                        allOf(greaterThan(70.0f), lessThan(85.0f)))
                .body("users.find { it.userId == 'user_rooftop' }.ageSeconds", greaterThanOrEqualTo(0))
                .body("users.find { it.userId == 'user_rooftop' }.expiresInSeconds", greaterThan(0))
                .body("users.find { it.userId == 'user_rooftop' }.freshnessState", equalTo("fresh"))
                .body("users.distanceMeters", everyItem(lessThanOrEqualTo(100.0f)))
                .body("users.relativeX", everyItem(greaterThanOrEqualTo(-1.0f)))
                .body("users.relativeX", everyItem(lessThanOrEqualTo(1.0f)))
                .body("users.relativeY", everyItem(greaterThanOrEqualTo(-1.0f)))
                .body("users.relativeY", everyItem(lessThanOrEqualTo(1.0f)));
    }

    @Test
    void nearbyUsesCameraOrientationAndAltitudeWhenProvided() {
        String suffix = UUID.randomUUID().toString();
        String eastId = "nearby_camera_east_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Nearby East",
                          "avatarUrl": "https://cdn.jezaku.local/avatars/nearby-east.jpg",
                          "position": {
                            "latitude": 10.0,
                            "longitude": 20.00046,
                            "altitudeMeters": 105.5
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(eastId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/presence/nearby?lat=10.0&lng=20.0&altitudeMeters=100.0"
                        + "&headingDegrees=88&compassDegrees=90&radiusMeters=100&viewerId=camera_viewer_%s"
                                .formatted(suffix))
                .then()
                .statusCode(200)
                .body("center.altitudeMeters", equalTo(100.0f))
                .body("headingDegrees", equalTo(88.0f))
                .body("compassDegrees", equalTo(90.0f))
                .body("orientationDegrees", equalTo(90.0f))
                .body("users.find { it.userId == '%s' }.distanceBucket".formatted(eastId), equalTo("mid"))
                .body("users.find { it.userId == '%s' }.relativeBearingDegrees".formatted(eastId), equalTo(0.0f))
                .body("users.find { it.userId == '%s' }.relativeX".formatted(eastId),
                        allOf(greaterThan(-0.05f), lessThan(0.05f)))
                .body("users.find { it.userId == '%s' }.relativeY".formatted(eastId), lessThan(-0.45f))
                .body("users.find { it.userId == '%s' }.altitudeDeltaMeters".formatted(eastId), equalTo(5.5f));
    }

    @Test
    void nearbyLimitsResultsAndReportsTruncation() {
        String suffix = UUID.randomUUID().toString();
        String firstId = "nearby_limit_first_" + suffix;
        String secondId = "nearby_limit_second_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Nearby Limit First",
                          "position": {
                            "latitude": 12.0,
                            "longitude": 22.00020
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(firstId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Nearby Limit Second",
                          "position": {
                            "latitude": 12.0,
                            "longitude": 22.00030
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(secondId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/presence/nearby?lat=12.0&lng=22.0&radiusMeters=100&limit=1&viewerId=nearby_limit_viewer_%s"
                        .formatted(suffix))
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("totalAvailableCount", equalTo(2))
                .body("truncated", equalTo(true))
                .body("summary.count", equalTo(1))
                .body("users.size()", equalTo(1))
                .body("users[0].userId", equalTo(firstId));
    }

    @Test
    void minimapRotatesDotsByViewerCompass() {
        String suffix = UUID.randomUUID().toString();
        String viewerId = "minimap_viewer_" + suffix;
        String aheadId = "minimap_ahead_" + suffix;
        String leftId = "minimap_left_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Minimap Viewer",
                          "avatarUrl": "https://cdn.jezaku.local/avatars/minimap-viewer.jpg",
                          "position": {
                            "latitude": 11.0,
                            "longitude": 21.0,
                            "altitudeMeters": 100.0
                          },
                          "headingDegrees": 88,
                          "compassDegrees": 90,
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(viewerId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Ahead Dot",
                          "avatarUrl": "https://cdn.jezaku.local/avatars/ahead.jpg",
                          "position": {
                            "latitude": 11.0,
                            "longitude": 21.00046,
                            "altitudeMeters": 105.5
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(aheadId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Left Dot",
                          "avatarUrl": "https://cdn.jezaku.local/avatars/left.jpg",
                          "position": {
                            "latitude": 11.00045,
                            "longitude": 21.0,
                            "altitudeMeters": 94.0
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(leftId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/presence/users/{userId}/minimap?radiusMeters=100", viewerId)
                .then()
                .statusCode(200)
                .body("viewerId", equalTo(viewerId))
                .body("center.altitudeMeters", equalTo(100.0f))
                .body("compassDegrees", equalTo(90.0f))
                .body("orientationDegrees", equalTo(90.0f))
                .body("radiusMeters", equalTo(100.0f))
                .body("summary.count", equalTo(2))
                .body("summary.freshCount", equalTo(2))
                .body("summary.perimeterCount", equalTo(0))
                .body("dots.userId", hasItems(aheadId, leftId))
                .body("dots.find { it.userId == '%s' }.visibility".formatted(aheadId), equalTo("public"))
                .body("dots.find { it.userId == '%s' }.shareRadiusMeters".formatted(aheadId), equalTo(100))
                .body("dots.find { it.userId == '%s' }.statusMessage".formatted(aheadId), equalTo(""))
                .body("dots.find { it.userId == '%s' }.relativeBearingDegrees".formatted(aheadId), equalTo(0.0f))
                .body("dots.find { it.userId == '%s' }.relativeX".formatted(aheadId),
                        allOf(greaterThan(-0.05f), lessThan(0.05f)))
                .body("dots.find { it.userId == '%s' }.relativeY".formatted(aheadId), lessThan(-0.45f))
                .body("dots.find { it.userId == '%s' }.distanceRatio".formatted(aheadId),
                        allOf(greaterThan(0.45f), lessThan(0.6f)))
                .body("dots.find { it.userId == '%s' }.distanceBucket".formatted(aheadId), equalTo("mid"))
                .body("dots.find { it.userId == '%s' }.perimeter".formatted(aheadId), equalTo(false))
                .body("dots.find { it.userId == '%s' }.freshnessState".formatted(aheadId), equalTo("fresh"))
                .body("dots.find { it.userId == '%s' }.altitudeDeltaMeters".formatted(aheadId), equalTo(5.5f))
                .body("dots.find { it.userId == '%s' }.relativeBearingDegrees".formatted(leftId), equalTo(270.0f))
                .body("dots.find { it.userId == '%s' }.relativeX".formatted(leftId), lessThan(-0.45f));
    }

    @Test
    void minimapLimitsResultsAndReportsTruncation() {
        String suffix = UUID.randomUUID().toString();
        String viewerId = "minimap_limit_viewer_" + suffix;
        String firstId = "minimap_limit_first_" + suffix;
        String secondId = "minimap_limit_second_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Minimap Limit Viewer",
                          "position": {
                            "latitude": 13.0,
                            "longitude": 23.0
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(viewerId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Minimap Limit First",
                          "position": {
                            "latitude": 13.0,
                            "longitude": 23.00020
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(firstId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Minimap Limit Second",
                          "position": {
                            "latitude": 13.0,
                            "longitude": 23.00030
                          },
                          "visibility": "public",
                          "shareRadiusMeters": 100
                        }
                        """.formatted(secondId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/presence/users/{userId}/minimap?radiusMeters=100&limit=1", viewerId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("totalAvailableCount", equalTo(2))
                .body("truncated", equalTo(true))
                .body("summary.count", equalTo(1))
                .body("dots.size()", equalTo(1))
                .body("dots[0].userId", equalTo(firstId));
    }

    @Test
    void nearbyRequiresViewerCoordinates() {
        given()
                .header("X-Request-Id", "presence-missing-coordinates")
                .when()
                .get("/presence/nearby")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("presence-missing-coordinates"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/presence/nearby"))
                .body("requestId", equalTo("presence-missing-coordinates"));
    }

    @Test
    void rejectsInvalidNearbyLimit() {
        given()
                .when()
                .get("/presence/nearby?lat=-6.890620&lng=107.610790&limit=0")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("path", equalTo("/presence/nearby"));
    }

    @Test
    void visibilityUpdateHidesPresenceFromNearby() {
        String userId = "visibility_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Visibility Test",
                          "position": {
                            "latitude": -6.890600,
                            "longitude": 107.610820
                          },
                          "visibility": "public"
                        }
                        """.formatted(userId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "visibility": "private",
                          "shareRadiusMeters": 50
                        }
                        """)
                .when()
                .put("/presence/users/{userId}/visibility", userId)
                .then()
                .statusCode(200)
                .body("visibility", equalTo("private"))
                .body("shareRadiusMeters", equalTo(50));

        given()
                .when()
                .get("/presence/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100&viewerId=user_current")
                .then()
                .statusCode(200)
                .body("users.userId", not(hasItem(userId)));
    }

    @Test
    void stalePresenceReturnsOfflineAndIsExcludedNearby() {
        given()
                .when()
                .get("/presence/users/user_stale")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_stale"))
                .body("online", equalTo(false));

        given()
                .when()
                .get("/presence/nearby?lat=-6.890620&lng=107.610790&radiusMeters=100")
                .then()
                .statusCode(200)
                .body("users.userId", not(hasItem("user_stale")));
    }

    @Test
    void deleteRemovesPresence() {
        String userId = "delete_presence_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "displayName": "Delete Me",
                          "position": {
                            "latitude": -6.890610,
                            "longitude": 107.610800
                          }
                        }
                        """.formatted(userId))
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(201);

        given()
                .when()
                .delete("/presence/users/{userId}", userId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/presence/users/{userId}", userId)
                .then()
                .statusCode(404)
                .body("code", equalTo("NOT_FOUND"));
    }

    @Test
    void rejectsInvalidCoordinatesAndShareRadius() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "invalid_presence",
                          "position": {
                            "latitude": -95.0,
                            "longitude": 107.610800
                          },
                          "shareRadiusMeters": 0
                        }
                        """)
                .when()
                .post("/presence/check-ins")
                .then()
                .statusCode(400)
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/presence/check-ins"));
    }
}
