package tech.kayys.jezaku.identity;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;

@QuarkusTest
@TestProfile(IdentityAuthEnforcedTest.Enforced.class)
class IdentityAuthEnforcedTest {
    public static class Enforced implements QuarkusTestProfile {
        @Override
        public Map<String, String> getConfigOverrides() {
            return Map.of("jezaku.auth.required", "true");
        }
    }

    private static String login(String identifier, String password) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {"identifier": "%s", "password": "%s", "deviceId": "pixel-1"}
                        """.formatted(identifier, password))
                .when()
                .post("/identity/sessions")
                .then()
                .statusCode(200)
                .extract()
                .path("accessToken");
    }

    @Test
    void accessTokensAreSignedJwts() {
        String token = login("alya", "jezakuPass123");

        // header.payload.signature, not the old opaque "access_<hex>" value
        org.junit.jupiter.api.Assertions.assertEquals(3, token.split("\\.").length);
    }

    @Test
    void protectedEndpointsRequireAToken() {
        given().when().get("/identity/accounts/user_current")
                .then()
                .statusCode(401)
                .body("code", equalTo("UNAUTHORIZED"));

        given().header("Authorization", "Bearer not-a-token")
                .when().get("/identity/accounts/user_current")
                .then()
                .statusCode(401);
    }

    @Test
    void sessionCreationAndHealthStayPublic() {
        login("alya", "jezakuPass123");

        given().when().get("/q/health/live").then().statusCode(200);
    }

    @Test
    void callerCanReadOnlyTheirOwnAccount() {
        String alya = login("alya", "jezakuPass123");

        given().header("Authorization", "Bearer " + alya)
                .when().get("/identity/accounts/user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"));

        given().header("Authorization", "Bearer " + alya)
                .when().get("/identity/accounts/guardian_1")
                .then()
                .statusCode(403);
    }

    @Test
    void callerCannotChangeAnotherAccountsStatus() {
        String alya = login("alya", "jezakuPass123");

        given().header("Authorization", "Bearer " + alya)
                .when().put("/identity/accounts/guardian_1/status?status=suspended")
                .then()
                .statusCode(403);

        given().when().put("/identity/accounts/guardian_1/status?status=suspended")
                .then()
                .statusCode(401);
    }

    @Test
    void sessionListingsDoNotExposeCredentials() {
        String alya = login("alya", "jezakuPass123");

        given().header("Authorization", "Bearer " + alya)
                .when().get("/identity/sessions/user_current")
                .then()
                .statusCode(200)
                .body("[0].sessionId", startsWith("session_"))
                .body("[0].accessToken", nullValue())
                .body("[0].refreshToken", nullValue());
    }

    @Test
    void cannotRegisterDeviceOrApproveGuardianLinkForSomeoneElse() {
        String alya = login("alya", "jezakuPass123");

        given().header("Authorization", "Bearer " + alya)
                .contentType(ContentType.JSON)
                .body("""
                        {"userId": "guardian_1", "deviceId": "evil", "platform": "android", "deviceName": "x"}
                        """)
                .when().put("/identity/devices")
                .then()
                .statusCode(403);

        given().header("Authorization", "Bearer " + alya)
                .contentType(ContentType.JSON)
                .body("""
                        {"guardianUserId": "guardian_1"}
                        """)
                .when().post("/identity/guardian-links/anything/approve")
                .then()
                .statusCode(403);
    }

    @Test
    void revokedSessionsFailValidation() {
        String username = "rev_" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        String userId = given().contentType(ContentType.JSON)
                .body("""
                        {"email": "%s@example.test", "username": "%s", "password": "strongPass123", "ageBand": "adult"}
                        """.formatted(username, username))
                .when().post("/identity/accounts").then().statusCode(201)
                .extract().path("userId");
        var session = given().contentType(ContentType.JSON)
                .body("""
                        {"identifier": "%s", "password": "strongPass123", "deviceId": "pixel-1"}
                        """.formatted(username))
                .when().post("/identity/sessions").then().statusCode(200)
                .extract().jsonPath();
        String token = session.getString("accessToken");
        String sessionId = session.getString("sessionId");

        given().when().get("/identity/sessions/validate?accessToken={t}", token)
                .then()
                .statusCode(200)
                .body("valid", equalTo(true))
                .body("userId", equalTo(userId));

        given().header("Authorization", "Bearer " + token)
                .when().delete("/identity/sessions/{userId}/{sessionId}", userId, sessionId)
                .then()
                .statusCode(204);

        given().when().get("/identity/sessions/validate?accessToken={t}", token)
                .then()
                .statusCode(200)
                .body("valid", equalTo(false))
                .body("reason", equalTo("revoked"));
    }
}
