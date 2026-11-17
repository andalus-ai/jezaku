package tech.kayys.jezaku.discovery;

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
class DiscoveryOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static RequestSpecification as(String userId) {
        Instant now = Instant.now();
        String token = JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
        return given().header("Authorization", "Bearer " + token).contentType(ContentType.JSON);
    }

    private static final String NEARBY = "/discovery/nearby?lat=-6.890620&lng=107.610790";

    @Test
    void personalisedDiscoveryBelongsToTheCaller() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).when().get(NEARBY + "&viewerId={v}", victim).then().statusCode(403);
        as(intruder).when().get("/discovery/users/{u}/for-you?lat=-6.89&lng=107.61", victim)
                .then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\", \"targetType\": \"memory\", \"targetId\": \"m1\", \"action\": \"like\"}"
                        .formatted(victim))
                .when().post("/discovery/feedback").then().statusCode(403);

        as(intruder).when().get(NEARBY).then().statusCode(200);
        as(victim).when().get(NEARBY + "&viewerId={v}", victim).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        given().when().get(NEARBY + "&viewerId=anyone").then().statusCode(200);
    }
}
