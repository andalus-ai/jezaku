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
 * Exercises content lifecycle HTTP endpoints for updates, deletes, and cascade cleanup.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialContentLifecycleResourceTest extends SocialResourceHttpTestSupport {
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
    void supportsContentUpdateAndDeleteCascade() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String contentId = "lifecycle_content_" + suffix;
        String oldTag = "lifecycleold" + suffix;
        String newTag = "lifecyclenew" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Original lifecycle #%s @user_lens"
                        }
                        """.formatted(contentId, oldTag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("contentId", equalTo(contentId))
                .body("tags", hasItem(oldTag));

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
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens",
                          "message": "Lifecycle share"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/shares", contentId)
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens",
                          "reason": "testing_cleanup"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/hides", contentId)
                .then()
                .statusCode(200);

        String reportId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "reporterId": "user_lens",
                          "reason": "other",
                          "detail": "Lifecycle cleanup report"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/reports", contentId)
                .then()
                .statusCode(201)
                .extract()
                .path("reportId");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "Lifecycle comment for @user_current"
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", contentId)
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "user_lens",
                          "caption": "Should not update"
                        }
                        """)
                .when()
                .patch("/social/content/{contentId}", contentId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "user_current",
                          "scope": "public",
                          "caption": "Updated lifecycle #%s @user_rooftop"
                        }
                        """.formatted(newTag))
                .when()
                .patch("/social/content/{contentId}", contentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(contentId))
                .body("scope", equalTo("public"))
                .body("targetId", equalTo(""))
                .body("caption", equalTo("Updated lifecycle #%s @user_rooftop".formatted(newTag)))
                .body("tags", hasItem(newTag))
                .body("tags", not(hasItem(oldTag)))
                .body("likeCount", equalTo(1))
                .body("commentCount", equalTo(1))
                .body("saveCount", equalTo(1))
                .body("shareCount", equalTo(1));

        given()
                .when()
                .get("/social/tags/{tag}/content?viewerId=user_current&limit=10", oldTag)
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(contentId)));

        given()
                .when()
                .get("/social/tags/{tag}/content?viewerId=user_current&limit=10", newTag)
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(contentId));

        given()
                .when()
                .get("/social/content/{contentId}/mentions?viewerId=user_current&limit=10", contentId)
                .then()
                .statusCode(200)
                .body("mentions.mentionedUserId", hasItem("user_current"))
                .body("mentions.mentionedUserId", hasItem("user_rooftop"))
                .body("mentions.mentionedUserId", not(hasItem("user_lens")));

        given()
                .when()
                .delete("/social/content/{contentId}?actorUserId=user_lens", contentId)
                .then()
                .statusCode(403);

        given()
                .when()
                .delete("/social/content/{contentId}?actorUserId=user_current", contentId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/content/{contentId}?viewerId=user_current", contentId)
                .then()
                .statusCode(404);

        given()
                .when()
                .get("/social/tags/{tag}/content?viewerId=user_current&limit=10", newTag)
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(contentId)));

        given()
                .when()
                .get("/social/users/user_lens/saved-content?limit=20")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(contentId)));

        given()
                .when()
                .get("/social/users/user_lens/hidden-content?limit=20")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(contentId)));

        given()
                .when()
                .get("/social/content-reports?status=open&limit=50")
                .then()
                .statusCode(200)
                .body("reports.reportId", not(hasItem(reportId)));

        given()
                .when()
                .get("/social/activity/user_current?mode=all&limit=50")
                .then()
                .statusCode(200)
                .body("activities.contentId", not(hasItem(contentId)));
    }
}
