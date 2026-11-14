package tech.kayys.jezaku.notifications;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

@QuarkusTest
class NotificationOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    @Test
    void ownerCanReadTheirInbox() {
        given().header("Authorization", tokenFor("user_current"))
                .when().get("/notifications/users/user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"));
    }

    @Test
    void anotherUsersTokenIsRefusedOnEveryOwnerEndpoint() {
        String other = tokenFor("someone_else");

        given().header("Authorization", other)
                .when().get("/notifications/users/user_current").then().statusCode(403);
        given().header("Authorization", other)
                .when().get("/notifications/users/user_current/preferences").then().statusCode(403);
        given().header("Authorization", other)
                .when().get("/notifications/devices/user_current").then().statusCode(403);
        given().header("Authorization", other)
                .when().delete("/notifications/users/user_current/notification_seed_friend")
                .then().statusCode(403);
        given().header("Authorization", other)
                .when().delete("/notifications/devices/user_current/pixel").then().statusCode(403);
        given().header("Authorization", other)
                .contentType(ContentType.JSON)
                .body("{}")
                .when().post("/notifications/users/user_current/read").then().statusCode(403);
        given().header("Authorization", other)
                .contentType(ContentType.JSON)
                .body("""
                        {"userId": "user_current", "platform": "android", "pushToken": "stolen-token"}
                        """)
                .when().post("/notifications/devices").then().statusCode(403);
    }

    @Test
    void anonymousAndInvalidTokenCallsStillWorkWhileEnforcementIsOff() {
        given().when().get("/notifications/users/user_current").then().statusCode(200);
        given().header("Authorization", "Bearer garbage")
                .when().get("/notifications/users/user_current").then().statusCode(200);
    }
}
