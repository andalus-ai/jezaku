package tech.kayys.jezaku.profile;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.auth.JwtTokens;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;

@QuarkusTest
class ProfileOwnershipTest {
    private static final byte[] SECRET =
            "test-only-insecure-secret-0123456789abcdef".getBytes(StandardCharsets.UTF_8);

    private static String tokenFor(String userId) {
        Instant now = Instant.now();
        return "Bearer " + JwtTokens.issue(SECRET,
                new JwtTokens.Claims(userId, "session_test", now, now.plusSeconds(600)));
    }

    private static void createChildProfile(String childId, String guardianId) {
        given().contentType(ContentType.JSON)
                .body("""
                        {"displayName": "Kid", "ageBand": "teen",
                         "parentalControls": {"enabled": true, "guardianUserId": "%s", "dailyMinutesLimit": 60,
                           "restrictPublicPosting": true, "requireGuardianForFriendRequests": true,
                           "blockedCategories": [], "quietHoursStart": "21:00", "quietHoursEnd": "06:00"}}
                        """.formatted(guardianId))
                .when().put("/profiles/{id}", childId).then().statusCode(200);
    }

    @Test
    void onlyTheOwnerEditsProfileAndPrivacy() {
        String me = "me_" + UUID.randomUUID();
        String other = tokenFor("someone_else");
        given().header("Authorization", tokenFor(me)).contentType(ContentType.JSON)
                .body("{\"displayName\": \"Mine\"}")
                .when().put("/profiles/{id}", me).then().statusCode(200);
        given().header("Authorization", other).contentType(ContentType.JSON)
                .body("{\"displayName\": \"Hijacked\"}")
                .when().put("/profiles/{id}", me).then().statusCode(403);
        given().header("Authorization", other)
                .when().get("/profiles/{id}/privacy", me).then().statusCode(403);
        given().header("Authorization", other).contentType(ContentType.JSON)
                .body("{\"locationSharing\": \"public\"}")
                .when().put("/profiles/{id}/privacy", me).then().statusCode(403);
        given().header("Authorization", other)
                .when().get("/profiles/{id}", me).then().statusCode(200);
    }

    @Test
    void aChildCannotSwitchOffTheirOwnParentalControls() {
        String child = "child_" + UUID.randomUUID();
        String guardian = "guardian_" + UUID.randomUUID();
        createChildProfile(child, guardian);
        String off = "{\"enabled\": false, \"guardianUserId\": \"\"}";

        given().header("Authorization", tokenFor(child)).contentType(ContentType.JSON).body(off)
                .when().put("/profiles/{id}/parental-controls", child).then().statusCode(403);
        given().header("Authorization", tokenFor(child)).contentType(ContentType.JSON)
                .body("{\"parentalControls\": " + off + "}")
                .when().put("/profiles/{id}", child).then().statusCode(403);
        given().header("Authorization", tokenFor("stranger")).contentType(ContentType.JSON).body(off)
                .when().put("/profiles/{id}/parental-controls", child).then().statusCode(403);

        given().header("Authorization", tokenFor(guardian)).contentType(ContentType.JSON)
                .body("{\"enabled\": true, \"guardianUserId\": \"" + guardian + "\", \"dailyMinutesLimit\": 30}")
                .when().put("/profiles/{id}/parental-controls", child).then().statusCode(200);
    }

    @Test
    void controlsAreVisibleToChildAndGuardianOnly() {
        String child = "child_" + UUID.randomUUID();
        String guardian = "guardian_" + UUID.randomUUID();
        createChildProfile(child, guardian);

        given().header("Authorization", tokenFor(child))
                .when().get("/profiles/{id}/parental-controls", child).then().statusCode(200);
        given().header("Authorization", tokenFor(guardian))
                .when().get("/profiles/{id}/parental-controls", child).then().statusCode(200);
        given().header("Authorization", tokenFor("stranger"))
                .when().get("/profiles/{id}/parental-controls", child).then().statusCode(403);
    }

    @Test
    void anonymousCallsStillWorkWhileEnforcementIsOff() {
        String id = "anon_" + UUID.randomUUID();
        given().contentType(ContentType.JSON).body("{\"displayName\": \"Anon\"}")
                .when().put("/profiles/{id}", id).then().statusCode(200);
        given().when().get("/profiles/{id}/privacy", id).then().statusCode(200);
    }
}
