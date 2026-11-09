package tech.kayys.jezaku.identity;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;

@QuarkusTest
class IdentityResourceTest {
    @Test
    void createsAccountWithoutReturningPassword() {
        String suffix = UUID.randomUUID().toString().replace("-", "");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "email": "new-%s@example.test",
                          "username": "New User %s",
                          "password": "strongPass123",
                          "displayName": "New Explorer",
                          "ageBand": "adult"
                        }
                        """.formatted(suffix, suffix.substring(0, 8)))
                .when()
                .post("/identity/accounts")
                .then()
                .statusCode(201)
                .body("userId", notNullValue())
                .body("email", equalTo("new-%s@example.test".formatted(suffix)))
                .body("username", equalTo("newuser%s".formatted(suffix.substring(0, 8))))
                .body("status", equalTo("active"))
                .body("emailVerified", equalTo(false))
                .body("password", equalTo(null));
    }

    @Test
    void logsInValidatesRefreshesAndRevokesSession() {
        String username = "session_" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        String userId = createAccount(username);

        String accessToken = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "identifier": "%s",
                          "password": "strongPass123",
                          "deviceId": "pixel-1"
                        }
                        """.formatted(username))
                .when()
                .post("/identity/sessions")
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("accessToken", notNullValue())
                .body("refreshToken", notNullValue())
                .extract()
                .path("accessToken");

        given()
                .when()
                .get("/identity/sessions/validate?accessToken={accessToken}", accessToken)
                .then()
                .statusCode(200)
                .body("valid", equalTo(true))
                .body("userId", equalTo(userId));

        String refreshToken = given()
                .when()
                .get("/identity/sessions/{userId}", userId)
                .then()
                .statusCode(200)
                .body("userId", hasItem(userId))
                .extract()
                .path("[0].refreshToken");

        String newSessionId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "refreshToken": "%s"
                        }
                        """.formatted(refreshToken))
                .when()
                .post("/identity/sessions/refresh")
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .extract()
                .path("sessionId");

        given()
                .when()
                .delete("/identity/sessions/{userId}/{sessionId}", userId, newSessionId)
                .then()
                .statusCode(204);
    }

    @Test
    void rejectsBadLoginAndSuspendedAccount() {
        given()
                .contentType(ContentType.JSON)
                .header("X-Request-Id", "identity-bad-login")
                .body("""
                        {
                          "identifier": "alya",
                          "password": "wrong-password"
                        }
                        """)
                .when()
                .post("/identity/sessions")
                .then()
                .statusCode(403)
                .header("X-Request-Id", equalTo("identity-bad-login"))
                .body("code", equalTo("FORBIDDEN"))
                .body("status", equalTo(403))
                .body("path", equalTo("/identity/sessions"))
                .body("requestId", equalTo("identity-bad-login"));

        String username = "suspended_" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String userId = createAccount(username);

        given()
                .when()
                .put("/identity/accounts/{userId}/status?status=suspended", userId)
                .then()
                .statusCode(200)
                .body("status", equalTo("suspended"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "identifier": "%s",
                          "password": "strongPass123"
                        }
                        """.formatted(username))
                .when()
                .post("/identity/sessions")
                .then()
                .statusCode(403);
    }

    @Test
    void createsAndApprovesGuardianLink() {
        String childUsername = "child_" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String childId = createAccount(childUsername);

        String linkId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "childUserId": "%s",
                          "guardianEmail": "guardian@example.test",
                          "note": "Guardian approval for teen account"
                        }
                        """.formatted(childId))
                .when()
                .post("/identity/guardian-links")
                .then()
                .statusCode(201)
                .body("childUserId", equalTo(childId))
                .body("guardianUserId", equalTo("guardian_1"))
                .body("status", equalTo("pending"))
                .extract()
                .path("id");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "guardianUserId": "guardian_1"
                        }
                        """)
                .when()
                .post("/identity/guardian-links/{linkId}/approve", linkId)
                .then()
                .statusCode(200)
                .body("status", equalTo("approved"));

        given()
                .when()
                .get("/identity/accounts/{userId}", childId)
                .then()
                .statusCode(200)
                .body("guardianUserId", equalTo("guardian_1"));
    }

    @Test
    void trustsAndUntrustsDevice() {
        String username = "device_" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String userId = createAccount(username);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "deviceId": "camera-phone",
                          "platform": "android",
                          "deviceName": "Camera Phone"
                        }
                        """.formatted(userId))
                .when()
                .put("/identity/devices")
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("trusted", equalTo(true));

        given()
                .when()
                .delete("/identity/devices/{userId}/camera-phone", userId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/identity/devices/{userId}", userId)
                .then()
                .statusCode(200)
                .body("find { it.deviceId == 'camera-phone' }.trusted", equalTo(false));
    }

    @Test
    void returnsIdentityOverview() {
        given()
                .when()
                .get("/identity/overview/user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("trustedDeviceCount", greaterThanOrEqualTo(1))
                .body("guardianLinks", hasSize(0));
    }

    @Test
    void rejectsDuplicateEmail() {
        String suffix = UUID.randomUUID().toString().replace("-", "");
        String email = "dupe-%s@example.test".formatted(suffix);
        String username = "dupe_" + suffix.substring(0, 8);
        createAccount(email, username);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "email": "%s",
                          "username": "%s2",
                          "password": "strongPass123",
                          "ageBand": "adult"
                        }
                        """.formatted(email, username))
                .when()
                .post("/identity/accounts")
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"))
                .body("status", equalTo(409))
                .body("path", equalTo("/identity/accounts"));
    }

    private String createAccount(String username) {
        return createAccount("%s@example.test".formatted(username), username);
    }

    private String createAccount(String email, String username) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "email": "%s",
                          "username": "%s",
                          "password": "strongPass123",
                          "displayName": "Test User",
                          "ageBand": "adult"
                        }
                        """.formatted(email, username))
                .when()
                .post("/identity/accounts")
                .then()
                .statusCode(201)
                .extract()
                .path("userId");
    }
}
