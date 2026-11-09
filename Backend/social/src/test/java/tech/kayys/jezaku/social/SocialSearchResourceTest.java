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
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;

/**
 * Exercises viewer-aware social search discovery and HTTP cursor pagination.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialSearchResourceTest extends SocialResourceHttpTestSupport {
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
    void supportsViewerAwareSearchDiscovery() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String tag = "searchsignal" + suffix;
        String publicContentId = "search_public_" + suffix;
        String privateContentId = "search_private_" + suffix;
        String privateNeedle = "privatesearch" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "post",
                          "scope": "public",
                          "caption": "Searchable public source #%s"
                        }
                        """.formatted(publicContentId, tag))
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
                          "caption": "%s hidden source"
                        }
                        """.formatted(privateContentId, privateNeedle))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/social/search?viewerId=user_lens&q={query}&types=tags,content&limit=10", tag)
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_lens"))
                .body("query", equalTo(tag))
                .body("types", hasItem("tags"))
                .body("types", hasItem("content"))
                .body("results.find { it.resultType == 'tag' && it.id == '%s' }.title".formatted(tag),
                        equalTo("#" + tag))
                .body("results.find { it.resultType == 'tag' && it.id == '%s' }.visibleContentCount"
                        .formatted(tag), greaterThanOrEqualTo(1))
                .body("results.find { it.resultType == 'content' && it.id == '%s' }.relation"
                        .formatted(publicContentId), equalTo("public"));

        given()
                .when()
                .get("/social/search?viewerId=user_lens&q=rooftop&types=users,groups&limit=20")
                .then()
                .statusCode(200)
                .body("results.find { it.resultType == 'user' && it.id == 'user_rooftop' }.title",
                        equalTo("Rooftop Friend"))
                .body("results.find { it.resultType == 'group' && it.id == 'group_rooftop_creators' }.title",
                        equalTo("Rooftop Creators"));

        given()
                .when()
                .get("/social/search?viewerId=user_current&q=user_blocked&types=users&limit=10")
                .then()
                .statusCode(200)
                .body("results.id", not(hasItem("user_blocked")));

        given()
                .when()
                .get("/social/search?viewerId=user_lens&q={query}&types=content&limit=10", privateNeedle)
                .then()
                .statusCode(200)
                .body("results.id", not(hasItem(privateContentId)));

        given()
                .when()
                .get("/social/search?viewerId=user_current&q={query}&types=content&limit=10", privateNeedle)
                .then()
                .statusCode(200)
                .body("results.id", hasItem(privateContentId))
                .body("results.find { it.id == '%s' }.relation".formatted(privateContentId),
                        equalTo("owner"));
    }

    @Test
    void paginatesSearchDiscoveryOverHttp() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String query = "cursorsearch" + suffix;
        String firstUserId = "search_cursor_a_" + suffix;
        String secondUserId = "search_cursor_b_" + suffix;
        String thirdUserId = "search_cursor_c_" + suffix;

        createSearchProfile(firstUserId, query + "a", "Cursor Search " + suffix);
        createSearchProfile(secondUserId, query + "b", "Cursor Search " + suffix);
        createSearchProfile(thirdUserId, query + "c", "Cursor Search " + suffix);

        Response firstPage = given()
                .when()
                .get("/social/search?viewerId=user_current&q={query}&types=users&limit=2", query)
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("query", equalTo(query))
                .body("count", equalTo(2))
                .body("limit", equalTo(2))
                .body("hasMore", equalTo(true))
                .body("nextCursor", not(equalTo("")))
                .body("results", hasSize(2))
                .body("results[0].id", equalTo(firstUserId))
                .body("results[1].id", equalTo(secondUserId))
                .extract()
                .response();

        String nextCursor = firstPage.path("nextCursor");
        given()
                .when()
                .get("/social/search?viewerId=user_current&q={query}&types=users&limit=2&cursor={cursor}",
                        query,
                        nextCursor)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(false))
                .body("nextCursor", equalTo(""))
                .body("results", hasSize(1))
                .body("results[0].id", equalTo(thirdUserId));
    }

}
