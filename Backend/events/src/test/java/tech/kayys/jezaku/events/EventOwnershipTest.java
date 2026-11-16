package tech.kayys.jezaku.events;

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
class EventOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static RequestSpecification as(String userId) {
        Instant now = Instant.now();
        String token = JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
        return given().header("Authorization", "Bearer " + token).contentType(ContentType.JSON);
    }

    @Test
    void eventActionsBelongToTheirUser() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).body("{\"organizerId\": \"%s\", \"title\": \"t\"}".formatted(victim))
                .when().post("/events").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\", \"status\": \"going\"}".formatted(victim))
                .when().post("/events/e1/rsvp").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\"}".formatted(victim))
                .when().post("/events/e1/check-ins").then().statusCode(403);
        as(intruder).body("{\"inviterId\": \"%s\", \"inviteeUserIds\": [\"x\"]}".formatted(victim))
                .when().post("/events/e1/invites").then().statusCode(403);
        as(intruder).when().get("/events/invitations/{u}", victim).then().statusCode(403);
        as(intruder).when().post("/events/e1/cancel?actorUserId={u}", victim).then().statusCode(403);
        as(intruder).when().get("/events/e1/activity?viewerUserId={u}", victim).then().statusCode(403);

        as(victim).when().get("/events/invitations/{u}", victim).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        given().when().get("/events/invitations/{u}", "anon_" + UUID.randomUUID()).then().statusCode(200);
    }
}
