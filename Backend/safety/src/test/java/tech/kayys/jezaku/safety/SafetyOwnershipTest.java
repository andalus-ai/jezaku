package tech.kayys.jezaku.safety;

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
class SafetyOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static RequestSpecification as(String userId) {
        Instant now = Instant.now();
        String token = JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
        return given().header("Authorization", "Bearer " + token).contentType(ContentType.JSON);
    }

    @Test
    void reportsAndZonesBelongToTheirUser() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).body("{\"reporterId\": \"%s\", \"targetType\": \"memory\", \"targetId\": \"m1\", \"reason\": \"spam\"}"
                        .formatted(victim))
                .when().post("/safety/reports").then().statusCode(403);
        as(intruder).body("{\"guardianId\": \"%s\", \"userId\": \"c\", \"name\": \"home\"}".formatted(victim))
                .when().post("/safety/zones").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\"}".formatted(victim))
                .when().post("/safety/zones/check").then().statusCode(403);
        as(intruder).when().get("/safety/zones/users/{u}", victim).then().statusCode(403);
        as(intruder).when().delete("/safety/zones/z1?guardianId={g}", victim).then().statusCode(403);

        as(victim).when().get("/safety/zones/users/{u}", victim).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        given().when().get("/safety/zones/users/{u}", "anon_" + UUID.randomUUID()).then().statusCode(200);
    }
}
