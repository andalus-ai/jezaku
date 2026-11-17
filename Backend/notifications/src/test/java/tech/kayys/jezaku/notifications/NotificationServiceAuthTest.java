package tech.kayys.jezaku.notifications;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;
import tech.kayys.jezaku.auth.ServiceScopes;
import tech.kayys.jezaku.auth.ServiceTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Set;

import static io.restassured.RestAssured.given;

@QuarkusTest
class NotificationServiceAuthTest {
    private static final byte[] USER_SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);
    private static final byte[] SERVICE_SECRET =
            "test-only-insecure-service-secret-0123456789abcd".getBytes(StandardCharsets.UTF_8);

    private static String user(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(USER_SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(300)));
    }

    private static String service(String... scopes) {
        Instant now = Instant.now();
        return "Bearer " + ServiceTokens.issue(SERVICE_SECRET,
                new ServiceTokens.Claims("messaging", Set.of(scopes), now, now.plusSeconds(300)));
    }

    private static final String INTAKE_BODY = "{}";

    @Test
    void userTokensCannotUseProducerEndpoints() {
        given().header("Authorization", user("user_current")).contentType(ContentType.JSON).body(INTAKE_BODY)
                .when().post("/notifications").then().statusCode(403);
        given().header("Authorization", user("user_current")).contentType(ContentType.JSON).body(INTAKE_BODY)
                .when().post("/notifications/intake/messaging").then().statusCode(403);
    }

    @Test
    void aServiceWithoutTheIntakeScopeIsRefused() {
        given().header("Authorization", service(ServiceScopes.SOCIAL_AUDIENCE))
                .contentType(ContentType.JSON).body(INTAKE_BODY)
                .when().post("/notifications/intake/messaging").then().statusCode(403);
    }

    @Test
    void aServiceWithTheIntakeScopeReachesTheHandler() {
        // The empty body is rejected by validation, which proves the scope check passed (not 401/403).
        int status = given().header("Authorization", service(ServiceScopes.NOTIFICATION_INTAKE))
                .contentType(ContentType.JSON).body(INTAKE_BODY)
                .when().post("/notifications/intake/messaging").then().extract().statusCode();
        org.junit.jupiter.api.Assertions.assertNotEquals(401, status);
        org.junit.jupiter.api.Assertions.assertNotEquals(403, status);
    }

    @Test
    void serviceTokensDoNotAuthenticateAsUsers() {
        // Without the act-for-user scope a service cannot read a user's inbox.
        given().header("Authorization", service(ServiceScopes.NOTIFICATION_INTAKE))
                .when().get("/notifications/users/user_current").then().statusCode(403);
    }
}
