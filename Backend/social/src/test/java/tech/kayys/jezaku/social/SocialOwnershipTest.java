package tech.kayys.jezaku.social;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class SocialOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static RequestSpecification as(String userId) {
        return given().header("Authorization", tokenFor(userId)).contentType(ContentType.JSON);
    }

    @Test
    void cannotActAsSomeoneElseInRequestBodies() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).body("{\"fromUserId\": \"%s\", \"toUserId\": \"x\"}".formatted(victim))
                .when().post("/social/friend-requests").then().statusCode(403);
        as(intruder).body("{\"followerId\": \"%s\"}".formatted(victim))
                .when().put("/social/users/someone/followers").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\", \"blockedUserId\": \"x\"}".formatted(victim))
                .when().put("/social/blocks").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\", \"targetType\": \"user\", \"targetId\": \"x\"}".formatted(victim))
                .when().put("/social/mutes").then().statusCode(403);
        as(intruder).body("{\"ownerId\": \"%s\", \"contentType\": \"post\", \"scope\": \"public\"}".formatted(victim))
                .when().post("/social/content").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\"}".formatted(victim))
                .when().put("/social/content/c1/likes").then().statusCode(403);
        as(intruder).body("{\"authorId\": \"%s\", \"text\": \"hi\"}".formatted(victim))
                .when().post("/social/content/c1/comments").then().statusCode(403);
        as(intruder).body("{\"name\": \"g\", \"ownerId\": \"%s\"}".formatted(victim))
                .when().post("/social/groups").then().statusCode(403);
    }

    @Test
    void cannotActAsSomeoneElseInPathsOrQueries() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).when().get("/social/blocks/{u}", victim).then().statusCode(403);
        as(intruder).when().get("/social/friend-requests/{u}", victim).then().statusCode(403);
        as(intruder).when().delete("/social/friends/{u}/x", victim).then().statusCode(403);
        as(intruder).when().get("/social/activity/{u}", victim).then().statusCode(403);
        as(intruder).when().get("/social/users/{u}/mutes", victim).then().statusCode(403);
        as(intruder).when().get("/social/users/{u}/saved-content", victim).then().statusCode(403);
        as(intruder).when().get("/social/users/{u}/groups", victim).then().statusCode(403);
        as(intruder).body("{}").when().put("/social/users/{u}/profile", victim).then().statusCode(403);
        as(intruder).when().post("/social/friend-requests/r1/accept?actorUserId={u}", victim)
                .then().statusCode(403);
        as(intruder).when().delete("/social/content/c1?actorUserId={u}", victim).then().statusCode(403);
        as(intruder).when().delete("/social/content/c1/likes/{u}", victim).then().statusCode(403);
    }

    @Test
    void readsAreEvaluatedForTheCaller() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).when().get("/social/feed?viewerId={v}", victim).then().statusCode(403);
        as(intruder).when().get("/social/search?q=a&viewerId={v}", victim).then().statusCode(403);
        as(intruder).when().get("/social/users/{u}/profile?viewerId={v}", victim, victim)
                .then().statusCode(403);
        as(intruder).when().get("/social/feed").then().statusCode(200);
    }

    @Test
    void usersCanReadTheirOwnPrivateLists() {
        String me = "me_" + UUID.randomUUID();

        as(me).when().get("/social/blocks/{u}", me).then().statusCode(200);
        as(me).when().get("/social/friend-requests/{u}", me).then().statusCode(200);
        as(me).when().get("/social/users/{u}/mutes", me).then().statusCode(200);
        as(me).when().get("/social/activity/{u}", me).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String me = "anon_" + UUID.randomUUID();
        given().when().get("/social/blocks/{u}", me).then().statusCode(200);
        given().when().get("/social/feed?viewerId={v}", me).then().statusCode(200);
    }
}
