package tech.kayys.jezaku.presence;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class PresenceOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String checkInBody(String userId) {
        return """
                {"userId": "%s", "displayName": "Walker",
                 "position": {"latitude": -6.89, "longitude": 107.61, "altitudeMeters": 700},
                 "visibility": "public", "shareRadiusMeters": 100}
                """.formatted(userId);
    }

    @Test
    void cannotCheckInAsSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(checkInBody(me))
                .when().post("/presence/check-ins").then().statusCode(403);
        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON).body(checkInBody(me))
                .when().post("/presence/check-ins").then().statusCode(201);
    }

    @Test
    void exactPositionVisibilityAndDeletionBelongToTheUser() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON).body(checkInBody(me))
                .when().post("/presence/check-ins").then().statusCode(201);
        String other = tokenFor("someone_else");

        given().header("Authorization", other).when().get("/presence/users/{id}", me).then().statusCode(403);
        given().header("Authorization", other).when().get("/presence/users/{id}/minimap", me).then().statusCode(403);
        given().header("Authorization", other).contentType(ContentType.JSON)
                .body("{\"visibility\": \"public\", \"shareRadiusMeters\": 500}")
                .when().put("/presence/users/{id}/visibility", me).then().statusCode(403);
        given().header("Authorization", other).when().delete("/presence/users/{id}", me).then().statusCode(403);

        given().header("Authorization", tokenFor(me)).when().get("/presence/users/{id}", me).then().statusCode(200);
    }

    @Test
    void nearbyCannotBeAskedOnBehalfOfAnotherViewer() {
        given().header("Authorization", tokenFor("someone_else"))
                .when().get("/presence/nearby?lat=-6.89&lng=107.61&viewerId=victim").then().statusCode(403);
        given().header("Authorization", tokenFor("someone_else"))
                .when().get("/presence/nearby?lat=-6.89&lng=107.61").then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String id = "anon_" + UUID.randomUUID();
        given().contentType(ContentType.JSON).body(checkInBody(id))
                .when().post("/presence/check-ins").then().statusCode(201);
        given().when().get("/presence/users/{id}", id).then().statusCode(200);
    }
}
