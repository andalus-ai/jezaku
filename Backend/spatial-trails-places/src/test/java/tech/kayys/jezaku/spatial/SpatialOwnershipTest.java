package tech.kayys.jezaku.spatial;

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
class SpatialOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static RequestSpecification as(String userId) {
        Instant now = Instant.now();
        String token = JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
        return given().header("Authorization", "Bearer " + token).contentType(ContentType.JSON);
    }

    @Test
    void anchorsAndTrailsBelongToTheirUser() {
        String victim = "victim_" + UUID.randomUUID();
        String intruder = "intruder_" + UUID.randomUUID();

        as(intruder).body("{\"ownerId\": \"%s\", \"title\": \"t\"}".formatted(victim))
                .when().post("/spatial/anchors").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\", \"title\": \"t\"}".formatted(victim))
                .when().post("/trails/completions").then().statusCode(403);
        as(intruder).body("{\"userId\": \"%s\", \"trailId\": \"t1\"}".formatted(victim))
                .when().post("/trails/saved").then().statusCode(403);
        as(intruder).when().get("/trails/history/{u}", victim).then().statusCode(403);
        as(intruder).when().delete("/trails/history/{u}", victim).then().statusCode(403);
        as(intruder).when().get("/trails/saved/{u}", victim).then().statusCode(403);
        as(intruder).when().delete("/trails/saved/{u}/t1", victim).then().statusCode(403);

        as(victim).when().get("/trails/history/{u}", victim).then().statusCode(200);
        as(victim).when().get("/trails/saved/{u}", victim).then().statusCode(200);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        given().when().get("/trails/history/{u}", "anon_" + UUID.randomUUID()).then().statusCode(200);
    }
}
