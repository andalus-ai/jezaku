package tech.kayys.jezaku.social;

import io.restassured.http.ContentType;
import org.junit.jupiter.api.BeforeEach;

import static io.restassured.RestAssured.given;

/**
 * Shared HTTP test fixture for social REST resource suites.
 */
abstract class SocialResourceHttpTestSupport {
    @BeforeEach
    void resetSocialGraph() {
        SocialGraphRepository repository = repository();
        if ("memory".equals(repository.backend())) {
            repository.clearForTest();
            service().seed();
        }
    }

    protected abstract SocialGraphRepository repository();

    protected abstract SocialService service();

    protected String createPendingRequest(String fromUserId, String toUserId) {
        return given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "fromUserId": "%s",
                          "toUserId": "%s"
                        }
                        """.formatted(fromUserId, toUserId))
                .when()
                .post("/social/friend-requests")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    protected void createSearchProfile(String userId, String handle, String displayName) {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "handle": "@%s",
                          "displayName": "%s",
                          "profileVisibility": "public"
                        }
                        """.formatted(userId, handle, displayName))
                .when()
                .put("/social/users/{userId}/profile", userId)
                .then()
                .statusCode(200);
    }
}
