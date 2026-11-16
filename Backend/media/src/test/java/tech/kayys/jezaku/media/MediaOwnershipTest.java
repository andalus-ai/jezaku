package tech.kayys.jezaku.media;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class MediaOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String uploadBody(String ownerId) {
        return """
                {"ownerId": "%s", "fileName": "own.jpg", "contentType": "image/jpeg",
                 "byteSize": 1024, "checksumSha256": "abc", "purpose": "memory_photo"}
                """.formatted(ownerId);
    }

    private static String ownerBody(String ownerId) {
        return "{\"ownerId\": \"%s\"}".formatted(ownerId);
    }

    private static String uploadAs(String ownerId) {
        return given().header("Authorization", tokenFor(ownerId)).contentType(ContentType.JSON)
                .body(uploadBody(ownerId))
                .when().post("/media/uploads").then().statusCode(201).extract().path("uploadId");
    }

    @Test
    void cannotRequestAnUploadForSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(uploadBody(me))
                .when().post("/media/uploads").then().statusCode(403);
    }

    @Test
    void cannotCompleteAnotherUsersUpload() {
        String me = "me_" + UUID.randomUUID();
        String uploadId = uploadAs(me);

        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(ownerBody(me))
                .when().post("/media/uploads/{id}/complete", uploadId).then().statusCode(403);
        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON).body(ownerBody(me))
                .when().post("/media/uploads/{id}/complete", uploadId).then().statusCode(200);
    }

    @Test
    void mediaLibraryAndDeletionBelongToTheOwner() {
        String me = "me_" + UUID.randomUUID();
        String uploadId = uploadAs(me);
        String mediaId = given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON)
                .body(ownerBody(me))
                .when().post("/media/uploads/{id}/complete", uploadId)
                .then().statusCode(200).extract().path("mediaId");

        given().header("Authorization", tokenFor("intruder"))
                .when().get("/media/users/{o}", me).then().statusCode(403);
        given().header("Authorization", tokenFor("intruder"))
                .when().delete("/media/{id}?ownerId={o}", mediaId, me).then().statusCode(403);

        given().header("Authorization", tokenFor(me))
                .when().get("/media/users/{o}", me).then().statusCode(200);
        given().header("Authorization", tokenFor(me))
                .when().delete("/media/{id}?ownerId={o}", mediaId, me).then().statusCode(204);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String me = "anon_" + UUID.randomUUID();
        given().contentType(ContentType.JSON).body(uploadBody(me))
                .when().post("/media/uploads").then().statusCode(201);
        given().when().get("/media/users/{o}", me).then().statusCode(200);
    }
}
