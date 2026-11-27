package tech.kayys.jezaku.memory;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

@QuarkusTest
class MemoryOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String body(String ownerId, String visibility) {
        return """
                {
                  "ownerId": "%s",
                  "mediaUrl": "https://cdn.jezaku.local/upload/photo.jpg",
                  "thumbnailUrl": "https://cdn.jezaku.local/upload/photo-thumb.jpg",
                  "caption": "ownership",
                  "position": {"latitude": -6.880100, "longitude": 107.611100, "altitudeMeters": 742.5},
                  "headingDegrees": 5,
                  "compassDegrees": 345,
                  "pitchDegrees": -12.5,
                  "rollDegrees": 1.25,
                  "gpsAccuracyMeters": 3.2,
                  "anchorType": "HYBRID",
                  "visibility": "%s"
                }
                """.formatted(ownerId, visibility);
    }

    private static String create(String ownerId, String visibility) {
        return given().header("Authorization", tokenFor(ownerId)).contentType(ContentType.JSON)
                .body(body(ownerId, visibility))
                .when().post("/memories").then().statusCode(201).extract().jsonPath().getString("id");
    }

    @Test
    void cannotCreateAMemoryForSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON)
                .body(body(me, "public"))
                .when().post("/memories").then().statusCode(403);
    }

    @Test
    void onlyTheOwnerCanChangeTheCaptionAndAudience() {
        String me = "me_" + UUID.randomUUID();
        String id = create(me, "public");

        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"%s\", \"caption\": \"hijacked\"}".formatted(me))
                .when().patch("/memories/{id}/details", id).then().statusCode(403);
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"intruder\", \"visibility\": \"private\"}")
                .when().patch("/memories/{id}/details", id).then().statusCode(403);

        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"%s\", \"visibility\": \"friends\"}".formatted(me))
                .when().patch("/memories/{id}/details", id).then().statusCode(200)
                .body("visibility", equalTo("friends"));
    }

    @Test
    void onlyTheOwnerCanChangeTheFrameLook() {
        String me = "me_" + UUID.randomUUID();
        String id = create(me, "public");

        // A signed-in user cannot act as the owner, nor name themselves as the owner.
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"%s\", \"frameStyle\": \"gold\"}".formatted(me))
                .when().patch("/memories/{id}/frame-style", id).then().statusCode(403);
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"intruder\", \"frameStyle\": \"gold\"}")
                .when().patch("/memories/{id}/frame-style", id).then().statusCode(403);

        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"%s\", \"frameStyle\": \"gold\"}".formatted(me))
                .when().patch("/memories/{id}/frame-style", id).then().statusCode(200)
                .body("frameStyle", equalTo("gold"));
    }

    @Test
    void privateMemoriesAreInvisibleToOthers() {
        String me = "me_" + UUID.randomUUID();
        String privateId = create(me, "private");
        String friendsId = create(me, "friends");
        String publicId = create(me, "public");

        given().header("Authorization", tokenFor("stranger"))
                .when().get("/memories/{id}", privateId).then().statusCode(404);
        given().header("Authorization", tokenFor("stranger"))
                .when().get("/memories/{id}", friendsId).then().statusCode(404);
        given().header("Authorization", tokenFor("stranger"))
                .when().get("/memories/{id}", publicId).then().statusCode(200);
        given().header("Authorization", tokenFor(me))
                .when().get("/memories/{id}", privateId).then().statusCode(200);

        given().header("Authorization", tokenFor("stranger"))
                .when().get("/memories/users/{u}", me).then().statusCode(200).body("count", equalTo(1));
        given().header("Authorization", tokenFor(me))
                .when().get("/memories/users/{u}", me).then().statusCode(200).body("count", equalTo(3));
    }

    @Test
    void onlyTheOwnerCanDeleteOrEditAnchors() {
        String me = "me_" + UUID.randomUUID();
        String id = create(me, "public");

        given().header("Authorization", tokenFor("intruder"))
                .when().delete("/memories/{id}", id).then().statusCode(403);
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON)
                .body("{\"ownerId\": \"%s\"}".formatted(me))
                .when().patch("/memories/{id}/anchor", id).then().statusCode(403);
        given().header("Authorization", tokenFor("intruder"))
                .when().get("/memories/{id}/anchor/history?ownerId={o}", id, me).then().statusCode(403);

        given().header("Authorization", tokenFor(me))
                .when().get("/memories/{id}/anchor/history?ownerId={o}", id, me).then().statusCode(200);
        given().header("Authorization", tokenFor(me))
                .when().delete("/memories/{id}", id).then().statusCode(204);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String me = "anon_" + UUID.randomUUID();
        String id = given().contentType(ContentType.JSON).body(body(me, "private"))
                .when().post("/memories").then().statusCode(201).extract().jsonPath().getString("id");
        given().when().get("/memories/{id}", id).then().statusCode(200);
        given().when().delete("/memories/{id}", id).then().statusCode(204);
    }
}
