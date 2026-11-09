package tech.kayys.jezaku.engagement;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

@QuarkusTest
class EngagementResourceTest {
    @Test
    void upsertsReactionAndUpdatesSummary() {
        String userId = "reactor_" + UUID.randomUUID();
        String targetId = "memory_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "targetType": "memory",
                          "targetId": "%s",
                          "reaction": "like"
                        }
                        """.formatted(userId, targetId))
                .when()
                .post("/engagement/reactions")
                .then()
                .statusCode(200)
                .body("reaction", equalTo("like"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "targetType": "memory",
                          "targetId": "%s",
                          "reaction": "love"
                        }
                        """.formatted(userId, targetId))
                .when()
                .post("/engagement/reactions")
                .then()
                .statusCode(200)
                .body("reaction", equalTo("love"));

        given()
                .when()
                .get("/engagement/targets/memory/{targetId}/summary?viewerId={userId}", targetId, userId)
                .then()
                .statusCode(200)
                .body("totalReactions", equalTo(1))
                .body("reactionCounts.like", equalTo(0))
                .body("reactionCounts.love", equalTo(1))
                .body("viewerReacted", equalTo(true))
                .body("viewerReaction", equalTo("love"));
    }

    @Test
    void createsAndListsComments() {
        String targetId = "event_" + UUID.randomUUID();

        String commentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_current",
                          "targetType": "event",
                          "targetId": "%s",
                          "body": "I can see the AR marker from here."
                        }
                        """.formatted(targetId))
                .when()
                .post("/engagement/comments")
                .then()
                .statusCode(201)
                .body("targetId", equalTo(targetId))
                .body("status", equalTo("active"))
                .extract()
                .path("commentId");

        given()
                .when()
                .get("/engagement/targets/event/{targetId}/comments", targetId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("comments.commentId", hasItem(commentId))
                .body("comments.body", hasItem("I can see the AR marker from here."));
    }

    @Test
    void enforcesCommentAuthorOnDelete() {
        String targetId = "memory_" + UUID.randomUUID();
        String commentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "comment_owner",
                          "targetType": "memory",
                          "targetId": "%s",
                          "body": "Temporary note."
                        }
                        """.formatted(targetId))
                .when()
                .post("/engagement/comments")
                .then()
                .statusCode(201)
                .extract()
                .path("commentId");

        given()
                .when()
                .delete("/engagement/comments/{commentId}?userId=intruder", commentId)
                .then()
                .statusCode(403)
                .body("code", equalTo("FORBIDDEN"));

        given()
                .when()
                .delete("/engagement/comments/{commentId}?userId=comment_owner", commentId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/engagement/targets/memory/{targetId}/comments", targetId)
                .then()
                .statusCode(200)
                .body("comments.commentId", not(hasItem(commentId)));
    }

    @Test
    void bookmarksTargetAndListsUserBookmarks() {
        String userId = "bookmark_" + UUID.randomUUID();
        String targetId = "place_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "targetType": "place",
                          "targetId": "%s"
                        }
                        """.formatted(userId, targetId))
                .when()
                .post("/engagement/bookmarks")
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("targetId", equalTo(targetId));

        given()
                .when()
                .get("/engagement/users/{userId}/bookmarks", userId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("bookmarks.targetId", hasItem(targetId));

        given()
                .when()
                .get("/engagement/targets/place/{targetId}/summary?viewerId={userId}", targetId, userId)
                .then()
                .statusCode(200)
                .body("bookmarkCount", equalTo(1))
                .body("viewerBookmarked", equalTo(true));
    }

    @Test
    void removesReactionAndBookmark() {
        String userId = "remove_" + UUID.randomUUID();
        String targetId = "trail_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "targetType": "trail",
                          "targetId": "%s",
                          "reaction": "wow"
                        }
                        """.formatted(userId, targetId))
                .when()
                .post("/engagement/reactions")
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "targetType": "trail",
                          "targetId": "%s"
                        }
                        """.formatted(userId, targetId))
                .when()
                .post("/engagement/bookmarks")
                .then()
                .statusCode(200);

        given()
                .when()
                .delete("/engagement/reactions?userId={userId}&targetType=trail&targetId={targetId}", userId, targetId)
                .then()
                .statusCode(204);

        given()
                .when()
                .delete("/engagement/bookmarks?userId={userId}&targetType=trail&targetId={targetId}", userId, targetId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/engagement/targets/trail/{targetId}/summary?viewerId={userId}", targetId, userId)
                .then()
                .statusCode(200)
                .body("totalReactions", equalTo(0))
                .body("bookmarkCount", equalTo(0))
                .body("viewerReacted", equalTo(false))
                .body("viewerBookmarked", equalTo(false));
    }

    @Test
    void rejectsInvalidTargetTypeWithRequestId() {
        given()
                .header("X-Request-Id", "engagement-bad-target")
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_current",
                          "targetType": "secret",
                          "targetId": "secret_1",
                          "reaction": "like"
                        }
                        """)
                .when()
                .post("/engagement/reactions")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("engagement-bad-target"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/engagement/reactions"))
                .body("requestId", equalTo("engagement-bad-target"));
    }

    @Test
    void returnsSeededEngagementSummary() {
        given()
                .when()
                .get("/engagement/targets/memory/memory_seed_courtyard/summary?viewerId=user_current")
                .then()
                .statusCode(200)
                .body("targetType", equalTo("memory"))
                .body("targetId", equalTo("memory_seed_courtyard"))
                .body("totalReactions", greaterThanOrEqualTo(2))
                .body("reactionCounts.like", greaterThanOrEqualTo(1))
                .body("reactionCounts.love", greaterThanOrEqualTo(1))
                .body("commentCount", greaterThanOrEqualTo(1))
                .body("bookmarkCount", greaterThanOrEqualTo(1))
                .body("viewerReacted", equalTo(true))
                .body("viewerReaction", equalTo("like"))
                .body("viewerBookmarked", equalTo(true));
    }
}
