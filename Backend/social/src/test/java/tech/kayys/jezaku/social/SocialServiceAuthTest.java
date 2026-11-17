package tech.kayys.jezaku.social;

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
import static org.junit.jupiter.api.Assertions.assertNotEquals;

@QuarkusTest
class SocialServiceAuthTest {
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
                new ServiceTokens.Claims("camera", Set.of(scopes), now, now.plusSeconds(300)));
    }

    @Test
    void userTokensCannotCallInternalAudienceEndpoints() {
        given().header("Authorization", user("user_1")).contentType(ContentType.JSON).body("{}")
                .when().post("/social/audience/access").then().statusCode(403);
        given().header("Authorization", user("user_1"))
                .when().get("/social/audience/decision?ownerId=a&viewerId=user_1").then().statusCode(403);
        given().header("Authorization", user("user_1"))
                .when().get("/social/relationships/context?viewerId=user_1&ownerId=a").then().statusCode(403);
        given().header("Authorization", user("user_1"))
                .when().get("/social/visibility?viewerId=user_1&ownerId=a").then().statusCode(403);
        given().header("Authorization", user("user_1"))
                .when().get("/social/graph/repository").then().statusCode(403);
    }

    @Test
    void aServiceNeedsTheAudienceScope() {
        given().header("Authorization", service(ServiceScopes.NOTIFICATION_INTAKE))
                .contentType(ContentType.JSON).body("{}")
                .when().post("/social/audience/access").then().statusCode(403);
        int status = given().header("Authorization", service(ServiceScopes.SOCIAL_AUDIENCE))
                .when().get("/social/graph/repository").then().extract().statusCode();
        assertNotEquals(401, status);
        assertNotEquals(403, status);
    }

    @Test
    void graphReadsAreForTheUserThemselvesOrATrustedService() {
        given().header("Authorization", user("intruder")).when().get("/social/graph/victim")
                .then().statusCode(403);
        given().header("Authorization", user("intruder")).when().get("/social/network/victim")
                .then().statusCode(403);
        given().header("Authorization", user("intruder")).when().get("/social/audience/preview?ownerId=victim")
                .then().statusCode(403);
        int own = given().header("Authorization", user("victim")).when().get("/social/graph/victim")
                .then().extract().statusCode();
        assertNotEquals(403, own);
        // A service may read a graph only when it may also act for users.
        given().header("Authorization", service(ServiceScopes.SOCIAL_AUDIENCE))
                .when().get("/social/graph/victim").then().statusCode(403);
        int trusted = given().header("Authorization",
                        service(ServiceScopes.SOCIAL_AUDIENCE, ServiceScopes.ACT_FOR_USER))
                .when().get("/social/graph/victim").then().extract().statusCode();
        assertNotEquals(403, trusted);
    }

    @Test
    void anonymousInternalCallsStillWorkWhileEnforcementIsOff() {
        int status = given().when().get("/social/graph/repository").then().extract().statusCode();
        assertNotEquals(403, status);
        assertNotEquals(401, status);
    }
}
