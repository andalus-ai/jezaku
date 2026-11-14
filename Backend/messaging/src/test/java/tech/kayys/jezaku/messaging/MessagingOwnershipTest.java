package tech.kayys.jezaku.messaging;

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
class MessagingOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String createThread(String creatorId, String friendId) {
        return given()
                .header("Authorization", tokenFor(creatorId))
                .contentType(ContentType.JSON)
                .body("""
                        {"creatorId": "%s", "threadType": "direct", "title": "Pair", "participantIds": ["%s"]}
                        """.formatted(creatorId, friendId))
                .when().post("/messaging/threads")
                .then().statusCode(201)
                .extract().path("threadId");
    }

    @Test
    void cannotCreateAThreadAsSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor(me))
                .contentType(ContentType.JSON)
                .body("""
                        {"creatorId": "victim", "threadType": "direct", "participantIds": ["%s"]}
                        """.formatted(me))
                .when().post("/messaging/threads")
                .then().statusCode(403);
    }

    @Test
    void cannotSendAsAnotherParticipant() {
        String alice = "alice_" + UUID.randomUUID();
        String bob = "bob_" + UUID.randomUUID();
        String threadId = createThread(alice, bob);

        given().header("Authorization", tokenFor(alice))
                .contentType(ContentType.JSON)
                .body("""
                        {"senderId": "%s", "body": "pretending to be bob"}
                        """.formatted(bob))
                .when().post("/messaging/threads/{id}/messages", threadId)
                .then().statusCode(403);

        given().header("Authorization", tokenFor(alice))
                .contentType(ContentType.JSON)
                .body("""
                        {"senderId": "%s", "body": "hello"}
                        """.formatted(alice))
                .when().post("/messaging/threads/{id}/messages", threadId)
                .then().statusCode(201);
    }

    @Test
    void onlyParticipantsCanReadAThreadEvenWithoutNamingAViewer() {
        String alice = "alice_" + UUID.randomUUID();
        String bob = "bob_" + UUID.randomUUID();
        String stranger = "stranger_" + UUID.randomUUID();
        String threadId = createThread(alice, bob);

        given().header("Authorization", tokenFor(stranger))
                .when().get("/messaging/threads/{id}", threadId).then().statusCode(403);
        given().header("Authorization", tokenFor(stranger))
                .when().get("/messaging/threads/{id}/messages", threadId).then().statusCode(403);
        given().header("Authorization", tokenFor(stranger))
                .when().get("/messaging/threads/{id}/activity?viewerId={v}", threadId, alice)
                .then().statusCode(403);

        given().header("Authorization", tokenFor(bob))
                .when().get("/messaging/threads/{id}/messages", threadId)
                .then().statusCode(200).body("threadId", equalTo(threadId));
    }

    @Test
    void anotherUsersTokenIsRefusedOnPerUserEndpoints() {
        String alice = "alice_" + UUID.randomUUID();
        String bob = "bob_" + UUID.randomUUID();
        String threadId = createThread(alice, bob);
        String other = tokenFor(bob);

        given().header("Authorization", other)
                .when().get("/messaging/users/{u}/threads", alice).then().statusCode(403);
        given().header("Authorization", other)
                .when().get("/messaging/realtime/users/{u}/events", alice).then().statusCode(403);
        given().header("Authorization", other)
                .contentType(ContentType.JSON).body("{\"deliveryIds\": []}")
                .when().post("/messaging/realtime/users/{u}/ack", alice).then().statusCode(403);
        given().header("Authorization", other)
                .contentType(ContentType.JSON).body("{\"userId\": \"%s\"}".formatted(alice))
                .when().post("/messaging/threads/{id}/read", threadId).then().statusCode(403);
        given().header("Authorization", other)
                .contentType(ContentType.JSON).body("{\"userId\": \"%s\", \"muted\": true}".formatted(alice))
                .when().post("/messaging/threads/{id}/mute", threadId).then().statusCode(403);
        given().header("Authorization", other)
                .when().delete("/messaging/threads/{id}/messages/message_x?userId={u}", threadId, alice)
                .then().statusCode(403);

        given().header("Authorization", tokenFor(alice))
                .when().get("/messaging/users/{u}/threads", alice).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String alice = "alice_" + UUID.randomUUID();
        String bob = "bob_" + UUID.randomUUID();
        given().contentType(ContentType.JSON)
                .body("""
                        {"creatorId": "%s", "threadType": "direct", "participantIds": ["%s"]}
                        """.formatted(alice, bob))
                .when().post("/messaging/threads").then().statusCode(201);
        given().when().get("/messaging/users/{u}/threads", alice).then().statusCode(200);
    }
}
