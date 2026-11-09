package tech.kayys.jezaku.rewards;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;

@QuarkusTest
class RewardResourceTest {
    @Test
    void recordsMemoryRewardAndAwardsFirstMemoryBadge() {
        String userId = "reward_memory_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "action": "memory_created",
                          "sourceType": "memory",
                          "sourceId": "memory_capture_1"
                        }
                        """.formatted(userId))
                .when()
                .post("/rewards/events")
                .then()
                .statusCode(201)
                .body("userId", equalTo(userId))
                .body("action", equalTo("memory_created"))
                .body("xpAwarded", equalTo(40))
                .body("totalXp", equalTo(40))
                .body("level", equalTo(1))
                .body("duplicate", equalTo(false))
                .body("badgesAwarded.badgeId", hasItem("badge_first_memory"));
    }

    @Test
    void duplicateSourceEventDoesNotAwardMoreXp() {
        String userId = "reward_duplicate_" + UUID.randomUUID();
        String sourceId = "memory_" + UUID.randomUUID();
        String body = """
                {
                  "userId": "%s",
                  "action": "memory_created",
                  "sourceType": "memory",
                  "sourceId": "%s"
                }
                """.formatted(userId, sourceId);

        given()
                .contentType(ContentType.JSON)
                .body(body)
                .when()
                .post("/rewards/events")
                .then()
                .statusCode(201)
                .body("totalXp", equalTo(40));

        given()
                .contentType(ContentType.JSON)
                .body(body)
                .when()
                .post("/rewards/events")
                .then()
                .statusCode(201)
                .body("xpAwarded", equalTo(0))
                .body("totalXp", equalTo(40))
                .body("duplicate", equalTo(true));
    }

    @Test
    void profileSummarizesSeededUserRewards() {
        given()
                .when()
                .get("/rewards/users/user_current/profile")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("totalXp", greaterThanOrEqualTo(90))
                .body("level", equalTo(1))
                .body("badgeCount", greaterThanOrEqualTo(1))
                .body("badges.badgeId", hasItem("badge_first_memory"))
                .body("recentEvents.action", hasItem("memory_created"));
    }

    @Test
    void journeyCompletionAwardsJourneyBadge() {
        String userId = "reward_journey_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "action": "journey_completed",
                          "sourceType": "journey",
                          "sourceId": "journey_seed_anchor_loop"
                        }
                        """.formatted(userId))
                .when()
                .post("/rewards/events")
                .then()
                .statusCode(201)
                .body("xpAwarded", equalTo(120))
                .body("badgesAwarded.badgeId", hasItem("badge_anchor_loop"));

        given()
                .when()
                .get("/rewards/users/{userId}/badges", userId)
                .then()
                .statusCode(200)
                .body("badges.badgeId", hasItem("badge_anchor_loop"));
    }

    @Test
    void dailyPresenceEventsBuildStreak() {
        String userId = "reward_streak_" + UUID.randomUUID();
        for (int day = 0; day < 3; day++) {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "userId": "%s",
                              "action": "daily_presence",
                              "sourceType": "presence",
                              "sourceId": "presence_day_%s",
                              "occurredAt": "%s"
                            }
                            """.formatted(userId, day, Instant.now().minus(day, ChronoUnit.DAYS)))
                    .when()
                    .post("/rewards/events")
                    .then()
                    .statusCode(201);
        }

        given()
                .when()
                .get("/rewards/users/{userId}/profile", userId)
                .then()
                .statusCode(200)
                .body("streakDays", equalTo(3))
                .body("totalXp", equalTo(30));
    }

    @Test
    void leaderboardRanksSeededUsersByXp() {
        given()
                .when()
                .get("/rewards/leaderboard?scope=global&limit=5")
                .then()
                .statusCode(200)
                .body("scope", equalTo("global"))
                .body("count", greaterThanOrEqualTo(2))
                .body("entries[0].userId", equalTo("user_rooftop"))
                .body("entries[0].xp", greaterThanOrEqualTo(160));
    }

    @Test
    void exposesBadgeCatalog() {
        given()
                .when()
                .get("/rewards/badges")
                .then()
                .statusCode(200)
                .body("count", greaterThanOrEqualTo(6))
                .body("badges.badgeId", hasItem("badge_first_memory"))
                .body("badges.badgeId", hasItem("badge_anchor_loop"));
    }

    @Test
    void rejectsInvalidActionWithRequestId() {
        given()
                .header("X-Request-Id", "rewards-bad-action")
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_current",
                          "action": "teleport",
                          "sourceType": "memory",
                          "sourceId": "memory_seed_courtyard"
                        }
                        """)
                .when()
                .post("/rewards/events")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("rewards-bad-action"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/rewards/events"))
                .body("requestId", equalTo("rewards-bad-action"));
    }
}
