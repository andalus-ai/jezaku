package tech.kayys.jezaku.social;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;

/**
 * Exercises content interaction HTTP endpoints for access checks, likes, comments, replies, saves, and shares.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialContentInteractionResourceTest extends SocialResourceHttpTestSupport {
    @Inject
    SocialGraphRepository repository;

    @Inject
    SocialService service;

    @Override
    protected SocialGraphRepository repository() {
        return repository;
    }

    @Override
    protected SocialService service() {
        return service;
    }

    @Test
    void supportsContentAccessLikesAndComments() {
        String suffix = UUID.randomUUID().toString();
        String groupContentId = "content_group_" + suffix;
        String privateContentId = "content_private_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Rooftop angle"
                        }
                        """.formatted(groupContentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("contentId", equalTo(groupContentId))
                .body("ownerId", equalTo("user_current"))
                .body("owner.displayName", equalTo("Current User"))
                .body("owner.profileVisible", equalTo(true))
                .body("contentType", equalTo("photo"))
                .body("scope", equalTo("group"))
                .body("targetId", equalTo("group_rooftop_creators"))
                .body("likeCount", equalTo(0))
                .body("commentCount", equalTo(0))
                .body("audience.canView", equalTo(true));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "story",
                          "scope": "private",
                          "caption": "Draft only"
                        }
                        """.formatted(privateContentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("contentId", equalTo(privateContentId))
                .body("scope", equalTo("private"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "viewerId": "user_lens",
                          "contentIds": ["%s", "%s", "%s"]
                        }
                        """.formatted(groupContentId, privateContentId, groupContentId))
                .when()
                .post("/social/content/access")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_lens"))
                .body("count", equalTo(2))
                .body("visibleCount", equalTo(1))
                .body("hiddenCount", equalTo(1))
                .body("visibleContentIds", hasItem(groupContentId))
                .body("hiddenContentIds", hasItem(privateContentId))
                .body("decisions.find { it.contentId == '%s' }.reason".formatted(groupContentId),
                        equalTo("group_member"))
                .body("decisions.find { it.contentId == '%s' }.reason".formatted(privateContentId),
                        equalTo("private"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/likes", groupContentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(groupContentId))
                .body("userId", equalTo("user_lens"))
                .body("user.displayName", equalTo("Lens Friend"))
                .body("user.profileVisible", equalTo(true))
                .body("reactionType", equalTo("like"))
                .body("likeCount", equalTo(1));

        String commentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "I can see this group photo."
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", groupContentId)
                .then()
                .statusCode(201)
                .body("contentId", equalTo(groupContentId))
                .body("authorId", equalTo("user_lens"))
                .body("author.displayName", equalTo("Lens Friend"))
                .body("author.profileVisible", equalTo(true))
                .body("text", equalTo("I can see this group photo."))
                .extract()
                .path("commentId");

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_lens", groupContentId)
                .then()
                .statusCode(200)
                .body("owner.displayName", equalTo("Current User"))
                .body("owner.profileVisible", equalTo(true))
                .body("likeCount", equalTo(1))
                .body("commentCount", equalTo(1))
                .body("viewerLiked", equalTo(true))
                .body("audience.reason", equalTo("group_member"));

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens", groupContentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(groupContentId))
                .body("count", equalTo(1))
                .body("comments[0].commentId", equalTo(commentId))
                .body("comments[0].author.displayName", equalTo("Lens Friend"))
                .body("comments[0].author.profileVisible", equalTo(true))
                .body("comments[0].text", equalTo("I can see this group photo."));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_blocked"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/likes", groupContentId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_blocked",
                          "text": "Blocked users should not write here."
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", groupContentId)
                .then()
                .statusCode(403);

        given()
                .when()
                .delete("/social/content/{contentId}/comments/{commentId}?actorUserId=user_lens",
                        groupContentId, commentId)
                .then()
                .statusCode(204);

        given()
                .when()
                .delete("/social/content/{contentId}/likes/{userId}", groupContentId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_lens", groupContentId)
                .then()
                .statusCode(200)
                .body("likeCount", equalTo(0))
                .body("commentCount", equalTo(0))
                .body("viewerLiked", equalTo(false));
    }

    @Test
    void supportsThreadedCommentReplies() {
        String contentId = "threaded_comment_content_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Thread source"
                        }
                        """.formatted(contentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        String parentCommentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "Top-level thought"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", contentId)
                .then()
                .statusCode(201)
                .body("contentId", equalTo(contentId))
                .body("authorId", equalTo("user_lens"))
                .body("parentCommentId", equalTo(""))
                .body("replyCount", equalTo(0))
                .extract()
                .path("commentId");

        String replyCommentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_rooftop",
                          "text": "Replying into the thread",
                          "parentCommentId": "%s"
                        }
                        """.formatted(parentCommentId))
                .when()
                .post("/social/content/{contentId}/comments", contentId)
                .then()
                .statusCode(201)
                .body("contentId", equalTo(contentId))
                .body("authorId", equalTo("user_rooftop"))
                .body("parentCommentId", equalTo(parentCommentId))
                .body("replyCount", equalTo(0))
                .extract()
                .path("commentId");

        String secondParentCommentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "Second top-level comment"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", contentId)
                .then()
                .statusCode(201)
                .body("contentId", equalTo(contentId))
                .body("parentCommentId", equalTo(""))
                .extract()
                .path("commentId");

        Response firstCommentPage = given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&limit=1", contentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("parentCommentId", equalTo(""))
                .body("count", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("nextCursor", notNullValue())
                .body("comments.commentId", not(hasItem(replyCommentId)))
                .extract()
                .response();
        String firstTopCommentId = firstCommentPage.path("comments[0].commentId");
        String nextCommentCursor = firstCommentPage.path("nextCursor");

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&limit=1&cursor={cursor}",
                        contentId, nextCommentCursor)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("parentCommentId", equalTo(""))
                .body("count", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("nextCursor", equalTo(""))
                .body("comments.commentId", not(hasItem(firstTopCommentId)));

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&limit=10", contentId)
                .then()
                .statusCode(200)
                .body("count", equalTo(2))
                .body("comments.find { it.commentId == '%s' }.replyCount".formatted(parentCommentId), equalTo(1))
                .body("comments.commentId", not(hasItem(replyCommentId)));

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&parentCommentId={parentCommentId}&limit=10",
                        contentId, parentCommentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("parentCommentId", equalTo(parentCommentId))
                .body("count", equalTo(1))
                .body("comments[0].commentId", equalTo(replyCommentId))
                .body("comments[0].parentCommentId", equalTo(parentCommentId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/comments/{commentId}/likes", contentId, replyCommentId)
                .then()
                .statusCode(200)
                .body("commentId", equalTo(replyCommentId))
                .body("userId", equalTo("user_lens"))
                .body("user.displayName", equalTo("Lens Friend"))
                .body("user.profileVisible", equalTo(true))
                .body("reactionType", equalTo("like"))
                .body("likeCount", equalTo(1));

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&parentCommentId={parentCommentId}&limit=10",
                        contentId, parentCommentId)
                .then()
                .statusCode(200)
                .body("comments[0].commentId", equalTo(replyCommentId))
                .body("comments[0].likeCount", equalTo(1))
                .body("comments[0].viewerLiked", equalTo(true));

        given()
                .when()
                .get("/social/activity/user_rooftop?mode=inbox&limit=50")
                .then()
                .statusCode(200)
                .body("activities.find { it.commentId == '%s' && it.eventType == 'comment_liked' }.actorId"
                        .formatted(replyCommentId), equalTo("user_lens"))
                .body("activities.find { it.commentId == '%s' && it.eventType == 'comment_liked' }.recipientId"
                        .formatted(replyCommentId), equalTo("user_rooftop"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_blocked"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/comments/{commentId}/likes", contentId, replyCommentId)
                .then()
                .statusCode(403);

        given()
                .when()
                .delete("/social/content/{contentId}/comments/{commentId}/likes/{userId}",
                        contentId, replyCommentId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&parentCommentId={parentCommentId}&limit=10",
                        contentId, parentCommentId)
                .then()
                .statusCode(200)
                .body("comments[0].likeCount", equalTo(0))
                .body("comments[0].viewerLiked", equalTo(false));

        given()
                .when()
                .get("/social/activity/user_lens?mode=inbox&limit=50")
                .then()
                .statusCode(200)
                .body("activities.find { it.commentId == '%s' && it.eventType == 'comment_replied' }.actorId"
                        .formatted(replyCommentId), equalTo("user_rooftop"))
                .body("activities.find { it.commentId == '%s' && it.eventType == 'comment_replied' }.recipientId"
                        .formatted(replyCommentId), equalTo("user_lens"));

        given()
                .when()
                .delete("/social/content/{contentId}/comments/{commentId}?actorUserId=user_current",
                        contentId, parentCommentId)
                .then()
                .statusCode(204);

        given()
                .when()
                .delete("/social/content/{contentId}/comments/{commentId}?actorUserId=user_lens",
                        contentId, secondParentCommentId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_lens", contentId)
                .then()
                .statusCode(200)
                .body("commentCount", equalTo(0));

        given()
                .when()
                .get("/social/content/{contentId}/comments?viewerId=user_lens&limit=10", contentId)
                .then()
                .statusCode(200)
                .body("count", equalTo(0))
                .body("comments", hasSize(0));
    }

    @Test
    void supportsContentSavesSharesAndSavedLibrary() {
        String contentId = "save_share_content_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Save and share source"
                        }
                        """.formatted(contentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/saves", contentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("userId", equalTo("user_lens"))
                .body("user.displayName", equalTo("Lens Friend"))
                .body("user.profileVisible", equalTo(true))
                .body("saveCount", equalTo(1));

        String shareId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens",
                          "message": "Sharing this with my group."
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/shares", contentId)
                .then()
                .statusCode(201)
                .body("contentId", equalTo(contentId))
                .body("userId", equalTo("user_lens"))
                .body("user.displayName", equalTo("Lens Friend"))
                .body("user.profileVisible", equalTo(true))
                .body("message", equalTo("Sharing this with my group."))
                .body("shareCount", equalTo(1))
                .extract()
                .path("shareId");

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_lens", contentId)
                .then()
                .statusCode(200)
                .body("saveCount", equalTo(1))
                .body("shareCount", equalTo(1))
                .body("viewerSaved", equalTo(true));

        given()
                .when()
                .get("/social/users/user_lens/saved-content?limit=10")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("items.contentId", hasItem(contentId))
                .body("items.find { it.contentId == '%s' }.viewerSaved".formatted(contentId), equalTo(true));

        given()
                .when()
                .get("/social/content/{contentId}/shares?viewerId=user_lens", contentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("count", equalTo(1))
                .body("shares[0].shareId", equalTo(shareId))
                .body("shares[0].user.displayName", equalTo("Lens Friend"))
                .body("shares[0].user.profileVisible", equalTo(true))
                .body("shares[0].message", equalTo("Sharing this with my group."));

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("items.find { it.contentId == '%s' }.saveCount".formatted(contentId), equalTo(1))
                .body("items.find { it.contentId == '%s' }.shareCount".formatted(contentId), equalTo(1))
                .body("items.find { it.contentId == '%s' }.viewerSaved".formatted(contentId), equalTo(true));

        given()
                .when()
                .get("/social/activity/user_current?mode=inbox&limit=50")
                .then()
                .statusCode(200)
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_shared' }.actorId"
                        .formatted(contentId), equalTo("user_lens"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_shared' }.message"
                        .formatted(contentId), equalTo("Sharing this with my group."));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_blocked"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/saves", contentId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_blocked",
                          "message": "No access"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/shares", contentId)
                .then()
                .statusCode(403);

        given()
                .when()
                .delete("/social/content/{contentId}/saves/{userId}", contentId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_lens", contentId)
                .then()
                .statusCode(200)
                .body("saveCount", equalTo(0))
                .body("shareCount", equalTo(1))
                .body("viewerSaved", equalTo(false));
    }
}
