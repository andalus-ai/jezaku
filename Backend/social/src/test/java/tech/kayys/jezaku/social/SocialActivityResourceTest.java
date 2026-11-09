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
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;

/**
 * Exercises social activity inbox, outbox, summary, and read-state HTTP endpoints.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialActivityResourceTest extends SocialResourceHttpTestSupport {
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
    void recordsContentActivityAndMarksInboxItemsRead() {
        String contentId = "activity_content_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Activity source"
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
                .put("/social/content/{contentId}/likes", contentId)
                .then()
                .statusCode(200);

        String commentId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "Activity comment"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", contentId)
                .then()
                .statusCode(201)
                .extract()
                .path("commentId");

        Response firstActivityPage = given()
                .when()
                .get("/social/activity/user_current?mode=inbox&limit=1")
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("nextCursor", notNullValue())
                .body("unreadCount", greaterThanOrEqualTo(2))
                .extract()
                .response();
        String firstActivityPageId = firstActivityPage.path("activities[0].activityId");
        String nextActivityCursor = firstActivityPage.path("nextCursor");

        given()
                .when()
                .get("/social/activity/user_current?mode=inbox&limit=1&cursor={cursor}", nextActivityCursor)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("activities.activityId", not(hasItem(firstActivityPageId)))
                .body("unreadCount", greaterThanOrEqualTo(2));

        given()
                .when()
                .get("/social/activity/user_current/summary")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("inboxCount", greaterThanOrEqualTo(3))
                .body("unreadCount", greaterThanOrEqualTo(2))
                .body("eventTypes.find { it.eventType == 'content_liked' }.unreadCount",
                        greaterThanOrEqualTo(1))
                .body("eventTypes.find { it.eventType == 'content_commented' }.unreadCount",
                        greaterThanOrEqualTo(1));

        String likeActivityId = given()
                .when()
                .get("/social/activity/user_current?mode=inbox&limit=50")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("mode", equalTo("inbox"))
                .body("count", greaterThanOrEqualTo(3))
                .body("unreadCount", greaterThanOrEqualTo(2))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_created' }.read"
                        .formatted(contentId), equalTo(true))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.actorId"
                        .formatted(contentId), equalTo("user_lens"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.actor.displayName"
                        .formatted(contentId), equalTo("Lens Friend"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.actor.profileVisible"
                        .formatted(contentId), equalTo(true))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.recipient.displayName"
                        .formatted(contentId), equalTo("Current User"))
                .body("activities.find { it.commentId == '%s' }.eventType".formatted(commentId),
                        equalTo("content_commented"))
                .extract()
                .path("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.activityId"
                        .formatted(contentId));

        given()
                .when()
                .get("/social/activity/user_lens?mode=outbox&limit=50")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("mode", equalTo("outbox"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.recipientId"
                        .formatted(contentId), equalTo("user_current"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.actor.displayName"
                        .formatted(contentId), equalTo("Lens Friend"))
                .body("activities.find { it.contentId == '%s' && it.eventType == 'content_liked' }.recipient.displayName"
                        .formatted(contentId), equalTo("Current User"))
                .body("activities.find { it.commentId == '%s' }.recipientId".formatted(commentId),
                        equalTo("user_current"));

        given()
                .when()
                .put("/social/activity/{activityId}/read?actorUserId=user_lens", likeActivityId)
                .then()
                .statusCode(403);

        given()
                .when()
                .put("/social/activity/{activityId}/read?actorUserId=user_current", likeActivityId)
                .then()
                .statusCode(200)
                .body("activityId", equalTo(likeActivityId))
                .body("actor.displayName", equalTo("Lens Friend"))
                .body("recipient.displayName", equalTo("Current User"))
                .body("read", equalTo(true));

        given()
                .when()
                .put("/social/activity/user_current/read-all")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("markedReadCount", greaterThanOrEqualTo(1))
                .body("unreadCount", equalTo(0));

        given()
                .when()
                .get("/social/activity/user_current/summary")
                .then()
                .statusCode(200)
                .body("unreadCount", equalTo(0))
                .body("eventTypes.find { it.eventType == 'content_liked' }.unreadCount", equalTo(0))
                .body("eventTypes.find { it.eventType == 'content_commented' }.unreadCount", equalTo(0));
    }

}
