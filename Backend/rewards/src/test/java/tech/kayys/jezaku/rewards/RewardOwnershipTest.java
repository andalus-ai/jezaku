package tech.kayys.jezaku.rewards;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class RewardOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static String eventBody(String userId) {
        return """
                {"userId": "%s", "action": "memory_created", "sourceType": "memory", "sourceId": "mem_%s"}
                """.formatted(userId, UUID.randomUUID());
    }

    @Test
    void cannotAwardRewardEventsToSomeoneElse() {
        String me = "me_" + UUID.randomUUID();
        given().header("Authorization", tokenFor("intruder")).contentType(ContentType.JSON).body(eventBody(me))
                .when().post("/rewards/events").then().statusCode(403);
        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON).body(eventBody(me))
                .when().post("/rewards/events").then().statusCode(201);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String me = "anon_" + UUID.randomUUID();
        given().contentType(ContentType.JSON).body(eventBody(me))
                .when().post("/rewards/events").then().statusCode(201);
    }
}
