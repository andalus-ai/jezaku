package tech.kayys.jezaku.profile;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class ProfileResourceTest {
    @Test
    void returnsSeedProfileWithSafetySettings() {
        given()
                .when()
                .get("/profiles/user_current")
                .then()
                .statusCode(200)
                .body("displayName", equalTo("Alya Pathmaker"))
                .body("privacy.showOnMinimap", equalTo(true))
                .body("privacy.publicLocationPrecisionMeters", equalTo(50.0f))
                .body("parentalControls.enabled", equalTo(false));
    }

    @Test
    void upsertsProfileAndNormalizesUserFacingFields() {
        String userId = "new_profile_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "displayName": "  Mina Compass  ",
                          "handle": "Mina Compass!",
                          "bio": "Camera-first explorer",
                          "avatarUrl": "https://cdn.jezaku.local/avatars/mina.jpg",
                          "ageBand": "adult",
                          "interests": ["camera", "camera", "trail"],
                          "privacy": {
                            "locationSharing": "precise",
                            "showOnMinimap": true,
                            "publicLocationPrecisionMeters": 10,
                            "allowNearbyDiscovery": true,
                            "allowFriendRequests": true
                          },
                          "parentalControls": {
                            "enabled": false,
                            "dailyMinutesLimit": 120,
                            "restrictPublicPosting": false,
                            "requireGuardianForFriendRequests": false,
                            "blockedCategories": [],
                            "quietHoursStart": "22:00",
                            "quietHoursEnd": "06:00"
                          }
                        }
                        """)
                .when()
                .put("/profiles/{userId}", userId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("displayName", equalTo("Mina Compass"))
                .body("handle", equalTo("minacompass"))
                .body("interests", hasSize(2))
                .body("privacy.locationSharing", equalTo("precise"));
    }

    @Test
    void updatesPrivacyAndForcesMinimapOffWhenLocationSharingIsOff() {
        String userId = "privacy_user_" + UUID.randomUUID();
        createBasicProfile(userId);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "locationSharing": "off",
                          "showOnMinimap": true,
                          "publicLocationPrecisionMeters": 25,
                          "allowNearbyDiscovery": false,
                          "allowFriendRequests": false
                        }
                        """)
                .when()
                .put("/profiles/{userId}/privacy", userId)
                .then()
                .statusCode(200)
                .body("locationSharing", equalTo("off"))
                .body("showOnMinimap", equalTo(false))
                .body("publicLocationPrecisionMeters", equalTo(1000.0f));
    }

    @Test
    void updatesParentalControls() {
        String userId = "teen_profile_" + UUID.randomUUID();
        createBasicProfile(userId);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "enabled": true,
                          "guardianUserId": "guardian_42",
                          "dailyMinutesLimit": 75,
                          "restrictPublicPosting": true,
                          "requireGuardianForFriendRequests": true,
                          "blockedCategories": ["public_wall", "nearby_chat"],
                          "quietHoursStart": "20:30",
                          "quietHoursEnd": "06:30"
                        }
                        """)
                .when()
                .put("/profiles/{userId}/parental-controls", userId)
                .then()
                .statusCode(200)
                .body("enabled", equalTo(true))
                .body("guardianUserId", equalTo("guardian_42"))
                .body("dailyMinutesLimit", equalTo(75))
                .body("blockedCategories", hasSize(2));
    }

    @Test
    void rejectsUnsafeParentalLimit() {
        String userId = "limit_user_" + UUID.randomUUID();
        createBasicProfile(userId);

        given()
                .contentType(ContentType.JSON)
                .header("X-Request-Id", "profile-bad-limit")
                .body("""
                        {
                          "enabled": true,
                          "dailyMinutesLimit": 5,
                          "quietHoursStart": "22:00",
                          "quietHoursEnd": "06:00"
                        }
                        """)
                .when()
                .put("/profiles/{userId}/parental-controls", userId)
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("profile-bad-limit"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/profiles/" + userId + "/parental-controls"))
                .body("requestId", equalTo("profile-bad-limit"));
    }

    @Test
    void searchesDiscoverableProfiles() {
        given()
                .when()
                .get("/profiles/search?query=roof")
                .then()
                .statusCode(200)
                .body("query", equalTo("roof"))
                .body("count", greaterThanOrEqualTo(1))
                .body("results.userId", hasItem("user_rooftop"))
                .body("results.userId", not(hasItem("teen_explorer")));
    }

    @Test
    void unknownProfileReturnsNotFound() {
        given()
                .when()
                .get("/profiles/missing_user")
                .then()
                .statusCode(404)
                .body("code", equalTo("NOT_FOUND"))
                .body("status", equalTo(404))
                .body("path", equalTo("/profiles/missing_user"));
    }

    private void createBasicProfile(String userId) {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "displayName": "Basic User",
                          "handle": "%s",
                          "ageBand": "adult",
                          "interests": []
                        }
                        """.formatted(userId.replace("-", "")))
                .when()
                .put("/profiles/{userId}", userId)
                .then()
                .statusCode(200);
    }
}
