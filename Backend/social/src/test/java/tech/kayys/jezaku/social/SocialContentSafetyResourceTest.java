package tech.kayys.jezaku.social;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;

import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

/**
 * Exercises content safety HTTP endpoints for hides, reports, and mention visibility.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialContentSafetyResourceTest extends SocialResourceHttpTestSupport {
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
    void supportsContentHidesAndReports() {
        String contentId = "hide_report_content_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Hide and report source"
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
                          "userId": "user_lens",
                          "reason": "not_interested"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/hides", contentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("userId", equalTo("user_lens"))
                .body("reason", equalTo("not_interested"));

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_lens", contentId)
                .then()
                .statusCode(200)
                .body("viewerHidden", equalTo(true));

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(contentId)));

        given()
                .when()
                .get("/social/users/user_lens/hidden-content?limit=10")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("items.contentId", hasItem(contentId))
                .body("items.find { it.contentId == '%s' }.viewerHidden".formatted(contentId), equalTo(true));

        given()
                .when()
                .delete("/social/content/{contentId}/hides/{userId}", contentId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(contentId));

        String reportId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_lens",
                          "reason": "spam",
                          "detail": "This looks suspicious."
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/reports", contentId)
                .then()
                .statusCode(201)
                .body("contentId", equalTo(contentId))
                .body("reporterId", equalTo("user_lens"))
                .body("reason", equalTo("spam"))
                .body("detail", equalTo("This looks suspicious."))
                .body("status", equalTo("open"))
                .extract()
                .path("reportId");

        given()
                .when()
                .get("/social/content-reports?status=open&limit=50")
                .then()
                .statusCode(200)
                .body("status", equalTo("open"))
                .body("reports.reportId", hasItem(reportId))
                .body("reports.find { it.reportId == '%s' }.contentId".formatted(reportId), equalTo(contentId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_blocked",
                          "reason": "spam",
                          "detail": "No access"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/reports", contentId)
                .then()
                .statusCode(403);
    }

    @Test
    void supportsContentAndCommentMentions() {
        String contentId = "mention_content_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Rooftop loop for @user_lens @user_lens @user_blocked and @user_current"
                        }
                        """.formatted(contentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/social/content/{contentId}/mentions?viewerId=user_lens&limit=10", contentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("count", equalTo(1))
                .body("mentions[0].actorId", equalTo("user_current"))
                .body("mentions[0].actor.displayName", equalTo("Current User"))
                .body("mentions[0].actor.profileVisible", equalTo(true))
                .body("mentions[0].mentionedUserId", equalTo("user_lens"))
                .body("mentions[0].mentionedUser.displayName", equalTo("Lens Friend"))
                .body("mentions[0].mentionedUser.profileVisible", equalTo(true))
                .body("mentions[0].sourceType", equalTo("content"));

        given()
                .when()
                .get("/social/activity/user_lens?mode=inbox&limit=50")
                .then()
                .statusCode(200)
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_mentioned' }.actorId"
                        .formatted(contentId), equalTo("user_current"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_mentioned' }.recipientId"
                        .formatted(contentId), equalTo("user_lens"));

        String commentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "Looping in @user_current and @user_blocked."
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", contentId)
                .then()
                .statusCode(201)
                .extract()
                .path("commentId");

        given()
                .when()
                .get("/social/content/{contentId}/mentions?viewerId=user_lens&limit=10", contentId)
                .then()
                .statusCode(200)
                .body("count", equalTo(2))
                .body("mentions.mentionedUserId", hasItem("user_lens"))
                .body("mentions.mentionedUserId", hasItem("user_current"))
                .body("mentions.find { it.commentId == '%s' }.sourceType".formatted(commentId),
                        equalTo("comment"))
                .body("mentions.find { it.commentId == '%s' }.actor.displayName".formatted(commentId),
                        equalTo("Lens Friend"))
                .body("mentions.find { it.commentId == '%s' }.mentionedUser.displayName".formatted(commentId),
                        equalTo("Current User"))
                .body("mentions.mentionedUserId", not(hasItem("user_blocked")));

        given()
                .when()
                .get("/social/users/user_current/mentions?limit=50")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("mentions.find { it.commentId == '%s' }.contentId".formatted(commentId),
                        equalTo(contentId))
                .body("mentions.find { it.commentId == '%s' }.actorId".formatted(commentId),
                        equalTo("user_lens"))
                .body("mentions.find { it.commentId == '%s' }.actor.displayName".formatted(commentId),
                        equalTo("Lens Friend"))
                .body("mentions.find { it.commentId == '%s' }.mentionedUser.displayName".formatted(commentId),
                        equalTo("Current User"));

        given()
                .when()
                .get("/social/activity/user_current?mode=inbox&limit=50")
                .then()
                .statusCode(200)
                .body("activities.find { it.commentId == '%s' && it.eventType == 'comment_mentioned' }.actorId"
                        .formatted(commentId), equalTo("user_lens"))
                .body("activities.find { it.commentId == '%s' && it.eventType == 'comment_mentioned' }.recipientId"
                        .formatted(commentId), equalTo("user_current"));

        given()
                .when()
                .get("/social/content/{contentId}/mentions?viewerId=user_blocked&limit=10", contentId)
                .then()
                .statusCode(403);

        given()
                .when()
                .delete("/social/content/{contentId}/comments/{commentId}?actorUserId=user_lens",
                        contentId, commentId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/content/{contentId}/mentions?viewerId=user_lens&limit=10", contentId)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("mentions.commentId", not(hasItem(commentId)));
    }
}
