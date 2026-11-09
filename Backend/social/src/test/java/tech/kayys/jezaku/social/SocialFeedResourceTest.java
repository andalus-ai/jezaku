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
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

/**
 * Exercises the primary social feed HTTP endpoint and its audience-filtered pagination behavior.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialFeedResourceTest extends SocialResourceHttpTestSupport {
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
    void returnsAudienceFilteredSocialFeed() {
        String suffix = UUID.randomUUID().toString();
        String groupContentId = "feed_group_" + suffix;
        String privateContentId = "feed_private_" + suffix;
        String publicContentId = "feed_public_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Visible in group feed"
                        }
                        """.formatted(groupContentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "story",
                          "scope": "private",
                          "caption": "Owner-only feed item"
                        }
                        """.formatted(privateContentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_rooftop",
                          "contentType": "post",
                          "scope": "public",
                          "caption": "Public feed item"
                        }
                        """.formatted(publicContentId))
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
                .put("/social/content/{contentId}/likes", groupContentId)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "authorId": "user_lens",
                          "text": "This belongs in my group feed."
                        }
                        """)
                .when()
                .post("/social/content/{contentId}/comments", groupContentId)
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_lens"))
                .body("limit", equalTo(50))
                .body("count", greaterThanOrEqualTo(2))
                .body("visibleCount", greaterThanOrEqualTo(2))
                .body("hiddenCount", greaterThanOrEqualTo(1))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", hasItem(publicContentId))
                .body("items.contentId", not(hasItem(privateContentId)))
                .body("items.find { it.contentId == '%s' }.reason".formatted(groupContentId),
                        equalTo("group_member"))
                .body("items.find { it.contentId == '%s' }.likeCount".formatted(groupContentId), equalTo(1))
                .body("items.find { it.contentId == '%s' }.commentCount".formatted(groupContentId), equalTo(1))
                .body("items.find { it.contentId == '%s' }.viewerLiked".formatted(groupContentId), equalTo(true))
                .body("items.find { it.contentId == '%s' }.relation".formatted(publicContentId), equalTo("friend"))
                .body("items.find { it.contentId == '%s' }.score".formatted(groupContentId), greaterThan(0.0f));

        Response firstFeedPage = given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=1")
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("nextCursor", not(equalTo("")))
                .extract()
                .response();
        String firstFeedContentId = firstFeedPage.path("items[0].contentId");
        String nextFeedCursor = firstFeedPage.path("nextCursor");

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=1&cursor={cursor}", nextFeedCursor)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("items.contentId", not(hasItem(firstFeedContentId)));
    }

}
