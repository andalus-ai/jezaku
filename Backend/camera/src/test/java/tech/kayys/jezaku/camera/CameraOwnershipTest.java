package tech.kayys.jezaku.camera;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class CameraOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);
    private static final String CONTEXT = "/camera/context?lat=-6.890620&lng=107.610790";

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String sessionBody(String viewerId) {
        return """
                {"viewerId": "%s", "lat": -6.890620, "lng": 107.610790, "visibility": "private", "ttlSeconds": 180}
                """.formatted(viewerId);
    }

    private static String createSessionAs(String viewerId) {
        return given().header("Authorization", tokenFor(viewerId)).contentType(ContentType.JSON)
                .body(sessionBody(viewerId))
                .when().post("/camera/sessions")
                .then().statusCode(201).extract().jsonPath().getString("sessionId");
    }

    @Test
    void cannotOpenASessionForSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(sessionBody(me))
                .when().post("/camera/sessions").then().statusCode(403);
        createSessionAs(me);
    }

    @Test
    void sessionReadsAndWritesBelongToTheOwner() {
        String me = "me_" + UUID.randomUUID();
        String sessionId = createSessionAs(me);
        String intruder = tokenFor("intruder");
        String owner = tokenFor(me);

        for (String path : new String[] {
                "", "/context", "/minimap", "/minimap/expansion", "/memories/nearby", "/sync", "/events"}) {
            given().header("Authorization", intruder)
                    .when().get("/camera/sessions/{id}" + path, sessionId).then().statusCode(403);
        }
        for (String action : new String[] {"heartbeat", "pause", "resume", "end"}) {
            given().header("Authorization", intruder).contentType(ContentType.JSON).body("{}")
                    .when().post("/camera/sessions/{id}/" + action, sessionId).then().statusCode(403);
        }
        given().header("Authorization", intruder).contentType(ContentType.JSON).body("{}")
                .when().patch("/camera/sessions/{id}", sessionId).then().statusCode(403);

        given().header("Authorization", owner)
                .when().get("/camera/sessions/{id}", sessionId).then().statusCode(200);
        given().header("Authorization", owner)
                .when().get("/camera/sessions/{id}/events", sessionId).then().statusCode(200);
    }

    @Test
    void contextCannotBeEvaluatedForAnotherViewer() {
        given().header("Authorization", tokenFor("someone_else"))
                .when().get(CONTEXT + "&viewerId=victim").then().statusCode(403);
        given().header("Authorization", tokenFor("someone_else"))
                .when().get("/camera/minimap?lat=-6.890620&lng=107.610790&viewerId=victim").then().statusCode(403);
        given().header("Authorization", tokenFor("someone_else"))
                .when().get("/camera/memories/nearby?lat=-6.890620&lng=107.610790&viewerId=victim")
                .then().statusCode(403);
        given().header("Authorization", tokenFor("someone_else"))
                .when().get(CONTEXT).then().statusCode(200);
        given().header("Authorization", tokenFor("someone_else"))
                .when().get(CONTEXT + "&viewerId=someone_else").then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        given().when().get(CONTEXT + "&viewerId=anyone").then().statusCode(200);
        given().contentType(ContentType.JSON).body(sessionBody("anon_" + UUID.randomUUID()))
                .when().post("/camera/sessions").then().statusCode(201);
    }
}
