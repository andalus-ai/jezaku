package tech.kayys.jezaku.journeys;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class JourneyOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String startBody(String userId) {
        return "{\"userId\": \"%s\"}".formatted(userId);
    }

    private static String startAs(String caller, String userId) {
        return given().header("Authorization", tokenFor(caller)).contentType(ContentType.JSON)
                .body(startBody(userId))
                .when().post("/journeys/{id}/start", "journey_seed_anchor_loop")
                .then().extract().jsonPath().getString("sessionId");
    }

    @Test
    void cannotStartAJourneyForSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(startBody(me))
                .when().post("/journeys/{id}/start", "journey_seed_anchor_loop").then().statusCode(403);
        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON).body(startBody(me))
                .when().post("/journeys/{id}/start", "journey_seed_anchor_loop").then().statusCode(201);
    }

    @Test
    void cannotCompleteOrAbandonAnotherUsersSession() {
        String me = "me_" + UUID.randomUUID();
        String sessionId = startAs(me, me);
        String complete = """
                {"userId": "%s", "position": {"latitude": -6.890620, "longitude": 107.610790}}
                """.formatted(me);

        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(complete)
                .when().post("/journeys/sessions/{s}/checkpoints/{c}/complete", sessionId, "checkpoint_courtyard")
                .then().statusCode(403);
        given().header("Authorization", tokenFor("intruder"))
                .when().post("/journeys/sessions/{s}/abandon?userId={u}", sessionId, me).then().statusCode(403);

        given().header("Authorization", tokenFor(me))
                .when().post("/journeys/sessions/{s}/abandon?userId={u}", sessionId, me).then().statusCode(200);
    }

    @Test
    void journeyHistoryBelongsToTheUser() {
        String me = "me_" + UUID.randomUUID();
        startAs(me, me);

        given().header("Authorization", tokenFor("someone_else"))
                .when().get("/journeys/users/{u}", me).then().statusCode(403);
        given().header("Authorization", tokenFor(me))
                .when().get("/journeys/users/{u}", me).then().statusCode(200);
    }

    @Test
    void listCannotBeEvaluatedForAnotherViewer() {
        String url = "/journeys?lat=-6.890620&lng=107.610790&radiusMeters=250";
        given().header("Authorization", tokenFor("someone_else"))
                .when().get(url + "&viewerId=victim").then().statusCode(403);
        given().header("Authorization", tokenFor("someone_else"))
                .when().get(url).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String me = "anon_" + UUID.randomUUID();
        given().contentType(ContentType.JSON).body(startBody(me))
                .when().post("/journeys/{id}/start", "journey_seed_anchor_loop").then().statusCode(201);
        given().when().get("/journeys/users/{u}", me).then().statusCode(200);
    }
}
