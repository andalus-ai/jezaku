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
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;

/**
 * Exercises tag and topic HTTP endpoints for discovery, trending tags, follows, and topic feeds.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialTagTopicResourceTest extends SocialResourceHttpTestSupport {
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
    void supportsHashtagDiscoveryAndTrending() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String tag = "jezakudiscovery" + suffix;
        String secondTag = "rooftop" + suffix;
        String groupContentId = "tagged_group_" + suffix;
        String privateContentId = "tagged_private_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Discovery source #%s #%s #%s"
                        }
                        """.formatted(groupContentId, tag.toUpperCase(), secondTag, tag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("contentId", equalTo(groupContentId))
                .body("tags", hasItem(tag))
                .body("tags", hasItem(secondTag));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "story",
                          "scope": "private",
                          "caption": "Private tag source #%s"
                        }
                        """.formatted(privateContentId, tag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("tags", hasItem(tag));

        given()
                .when()
                .get("/social/tags/{tag}/content?viewerId=user_lens&limit=10", tag)
                .then()
                .statusCode(200)
                .body("tag", equalTo(tag))
                .body("viewerId", equalTo("user_lens"))
                .body("count", equalTo(1))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", not(hasItem(privateContentId)))
                .body("items.find { it.contentId == '%s' }.tags".formatted(groupContentId), hasItem(tag));

        given()
                .when()
                .get("/social/tags/{tag}/content?viewerId=user_current&limit=10", tag)
                .then()
                .statusCode(200)
                .body("count", equalTo(2))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", hasItem(privateContentId));

        given()
                .when()
                .get("/social/tags/trending?viewerId=user_lens&limit=20")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_lens"))
                .body("tags.tag", hasItem(tag))
                .body("tags.find { it.tag == '%s' }.contentCount".formatted(tag), equalTo(2))
                .body("tags.find { it.tag == '%s' }.visibleContentCount".formatted(tag), equalTo(1))
                .body("tags.find { it.tag == '%s' }.score".formatted(tag), greaterThan(0.0f));
    }

    @Test
    void supportsFollowedTopicsAndTopicFeed() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String followedTag = "followtopic" + suffix;
        String secondTag = "sharedtopic" + suffix;
        String groupContentId = "topic_group_" + suffix;
        String privateContentId = "topic_private_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Topic feed source #%s #%s"
                        }
                        """.formatted(groupContentId, followedTag, secondTag))
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
                          "caption": "Private topic feed source #%s"
                        }
                        """.formatted(privateContentId, followedTag))
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
                .put("/social/tags/{tag}/follows", followedTag)
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("tag", equalTo(followedTag));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/tags/{tag}/follows", secondTag)
                .then()
                .statusCode(200)
                .body("tag", equalTo(secondTag));

        given()
                .when()
                .get("/social/users/user_lens/followed-tags?limit=10")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("count", greaterThanOrEqualTo(2))
                .body("tags.tag", hasItem(followedTag))
                .body("tags.tag", hasItem(secondTag));

        given()
                .when()
                .get("/social/users/user_lens/topic-feed?limit=10")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("followedTags", hasItem(followedTag))
                .body("followedTags", hasItem(secondTag))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", not(hasItem(privateContentId)))
                .body("items.find { it.contentId == '%s' }.tags".formatted(groupContentId),
                        hasItem(followedTag));

        given()
                .when()
                .delete("/social/tags/{tag}/follows/{userId}", secondTag, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/users/user_lens/followed-tags?limit=10")
                .then()
                .statusCode(200)
                .body("tags.tag", hasItem(followedTag))
                .body("tags.tag", not(hasItem(secondTag)));
    }
}
