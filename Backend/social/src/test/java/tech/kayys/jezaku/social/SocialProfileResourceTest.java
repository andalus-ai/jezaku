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
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;

/**
 * Exercises user profile HTTP reads, owner updates, and profile visibility signals.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialProfileResourceTest extends SocialResourceHttpTestSupport {
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
    void privateProfilesRequireFollowRequestApproval() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String followedUserId = "private_followed_" + suffix;
        String followerUserId = "private_follower_" + suffix;
        String rejectedFollowerId = "private_rejected_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "handle": "followed%s",
                          "displayName": "Private Followed %s",
                          "profileVisibility": "private"
                        }
                        """.formatted(followedUserId, suffix, suffix))
                .when()
                .put("/social/users/{userId}/profile", followedUserId)
                .then()
                .statusCode(200)
                .body("profileVisibility", equalTo("private"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "handle": "follower%s",
                          "displayName": "Private Follower %s",
                          "avatarUrl": "https://cdn.jezaku.test/avatars/follower-%s.png",
                          "profileVisibility": "public"
                        }
                        """.formatted(followerUserId, suffix, suffix, suffix))
                .when()
                .put("/social/users/{userId}/profile", followerUserId)
                .then()
                .statusCode(200)
                .body("displayName", equalTo("Private Follower " + suffix));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "followerId": "%s"
                        }
                        """.formatted(followerUserId))
                .when()
                .put("/social/users/{followedUserId}/followers", followedUserId)
                .then()
                .statusCode(200)
                .body("followerId", equalTo(followerUserId))
                .body("followedUserId", equalTo(followedUserId))
                .body("status", equalTo("pending"))
                .body("follower.displayName", equalTo("Private Follower " + suffix))
                .body("follower.profileVisible", equalTo(true))
                .body("followedUser.displayName", equalTo("Private Followed " + suffix))
                .body("followedUser.profileVisible", equalTo(false));

        given()
                .when()
                .get("/social/users/{userId}/profile?viewerId={viewerId}", followedUserId, followerUserId)
                .then()
                .statusCode(200)
                .body("viewerFollowsUser", equalTo(false))
                .body("viewerFollowStatus", equalTo("pending"))
                .body("viewerFollowStatusUpdatedAt", notNullValue());

        given()
                .when()
                .get("/social/users/{userId}/followers", followedUserId)
                .then()
                .statusCode(200)
                .body("follows.followerId", not(hasItem(followerUserId)));

        given()
                .when()
                .get("/social/users/{userId}/follow-requests?direction=incoming&status=pending&limit=10",
                        followedUserId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(followedUserId))
                .body("direction", equalTo("incoming"))
                .body("status", equalTo("pending"))
                .body("requests.find { it.followerId == '%s' }.followedUserId".formatted(followerUserId),
                        equalTo(followedUserId))
                .body("requests.find { it.followerId == '%s' }.follower.displayName".formatted(followerUserId),
                        equalTo("Private Follower " + suffix))
                .body("requests.find { it.followerId == '%s' }.followedUser.profileVisible".formatted(followerUserId),
                        equalTo(true));

        given()
                .when()
                .get("/social/activity/{userId}?mode=inbox&limit=50", followedUserId)
                .then()
                .statusCode(200)
                .body("activities.find { it.actorId == '%s' && it.eventType == 'follow_requested' }.recipientId"
                        .formatted(followerUserId), equalTo(followedUserId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "decision": "approve"
                        }
                        """.formatted(followerUserId))
                .when()
                .put("/social/users/{followedUserId}/follow-requests/{followerId}/decision",
                        followedUserId, followerUserId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "decision": "approve"
                        }
                        """.formatted(followedUserId))
                .when()
                .put("/social/users/{followedUserId}/follow-requests/{followerId}/decision",
                        followedUserId, followerUserId)
                .then()
                .statusCode(200)
                .body("followerId", equalTo(followerUserId))
                .body("followedUserId", equalTo(followedUserId))
                .body("status", equalTo("following"));

        given()
                .when()
                .get("/social/users/{userId}/followers", followedUserId)
                .then()
                .statusCode(200)
                .body("follows.find { it.followerId == '%s' }.status".formatted(followerUserId),
                        equalTo("following"));

        given()
                .when()
                .get("/social/users/{userId}/profile?viewerId={viewerId}", followedUserId, followerUserId)
                .then()
                .statusCode(200)
                .body("viewerFollowsUser", equalTo(true))
                .body("viewerFollowStatus", equalTo("following"))
                .body("viewerFollowStatusUpdatedAt", notNullValue());

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "followerId": "%s"
                        }
                        """.formatted(rejectedFollowerId))
                .when()
                .put("/social/users/{followedUserId}/followers", followedUserId)
                .then()
                .statusCode(200)
                .body("status", equalTo("pending"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "decision": "reject"
                        }
                        """.formatted(followedUserId))
                .when()
                .put("/social/users/{followedUserId}/follow-requests/{followerId}/decision",
                        followedUserId, rejectedFollowerId)
                .then()
                .statusCode(200)
                .body("followerId", equalTo(rejectedFollowerId))
                .body("status", equalTo("rejected"));

        given()
                .when()
                .get("/social/users/{userId}/profile?viewerId={viewerId}", followedUserId, rejectedFollowerId)
                .then()
                .statusCode(200)
                .body("viewerFollowsUser", equalTo(false))
                .body("viewerFollowStatus", equalTo("rejected"))
                .body("viewerFollowStatusUpdatedAt", notNullValue());

        given()
                .when()
                .get("/social/users/{userId}/following", rejectedFollowerId)
                .then()
                .statusCode(200)
                .body("follows.followedUserId", not(hasItem(followedUserId)));
    }

    @Test
    void supportsProfileSummaryAndUserContentTimeline() {
        String suffix = UUID.randomUUID().toString();
        String publicContentId = "profile_public_" + suffix;
        String groupContentId = "profile_group_" + suffix;
        String privateContentId = "profile_private_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_lens",
                          "contentType": "post",
                          "scope": "public",
                          "caption": "Profile public source"
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
                          "contentId": "%s",
                          "ownerId": "user_lens",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Profile group source"
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
                          "ownerId": "user_lens",
                          "contentType": "story",
                          "scope": "private",
                          "caption": "Profile private source"
                        }
                        """.formatted(privateContentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/social/users/user_lens/content?viewerId=user_current&limit=50")
                .then()
                .statusCode(200)
                .body("ownerId", equalTo("user_lens"))
                .body("viewerId", equalTo("user_current"))
                .body("items.contentId", hasItem(publicContentId))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", not(hasItem(privateContentId)))
                .body("items.find { it.contentId == '%s' }.audience.canView".formatted(groupContentId),
                        equalTo(true));

        given()
                .when()
                .get("/social/users/user_lens/content?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(privateContentId))
                .body("items.find { it.contentId == '%s' }.audience.reason".formatted(privateContentId),
                        equalTo("owner"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "followerId": "user_current"
                        }
                        """)
                .when()
                .put("/social/users/{followedUserId}/followers", "user_lens")
                .then()
                .statusCode(200);

        given()
                .when()
                .get("/social/users/user_lens/followers?viewerId=user_current")
                .then()
                .statusCode(200)
                .body("follows.find { it.followerId == 'user_current' }.follower.displayName",
                        equalTo("Current User"))
                .body("follows.find { it.followerId == 'user_current' }.followedUser.displayName",
                        equalTo("Lens Friend"))
                .body("follows.find { it.followerId == 'user_current' }.followedUser.profileVisible",
                        equalTo(true));

        given()
                .when()
                .get("/social/users/user_lens/profile?viewerId=user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("viewerId", equalTo("user_current"))
                .body("displayName", equalTo("Lens Friend"))
                .body("viewerIsUser", equalTo(false))
                .body("viewerFollowsUser", equalTo(true))
                .body("viewerFollowStatus", equalTo("following"))
                .body("viewerFollowStatusUpdatedAt", notNullValue())
                .body("blocked", equalTo(false))
                .body("followerCount", greaterThanOrEqualTo(1))
                .body("authoredContentCount", greaterThanOrEqualTo(3))
                .body("publicContentCount", greaterThanOrEqualTo(1))
                .body("visibleContentCount", greaterThanOrEqualTo(2))
                .body("visibility.canViewProfile", equalTo(true));

        given()
                .when()
                .get("/social/users/user_lens/profile?viewerId=user_lens")
                .then()
                .statusCode(200)
                .body("viewerIsUser", equalTo(true))
                .body("relation", equalTo("self"))
                .body("viewerFollowStatus", equalTo("self"))
                .body("visibleContentCount", greaterThanOrEqualTo(3));
    }

    @Test
    void supportsEditableUserProfilesAndSearchHydration() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String userId = "profile_user_" + suffix;
        String duplicateUserId = "profile_duplicate_" + suffix;
        String handle = "lensmaker" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "handle": "@%s",
                          "displayName": "Lens Maker %s",
                          "bio": "Builds AR memory trails for searchable profile tests",
                          "avatarUrl": "https://cdn.jezaku.test/avatars/%s.png",
                          "websiteUrl": "https://jezaku.test/%s",
                          "locationLabel": "Bandung",
                          "profileVisibility": "public"
                        }
                        """.formatted(userId, handle, suffix, suffix, handle))
                .when()
                .put("/social/users/{userId}/profile", userId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("handle", equalTo(handle))
                .body("displayName", equalTo("Lens Maker " + suffix))
                .body("bio", equalTo("Builds AR memory trails for searchable profile tests"))
                .body("locationLabel", equalTo("Bandung"))
                .body("profileVisibility", equalTo("public"));

        given()
                .when()
                .get("/social/users/{userId}/profile?viewerId={viewerId}", userId, "user_current")
                .then()
                .statusCode(200)
                .body("userId", equalTo(userId))
                .body("displayName", equalTo("Lens Maker " + suffix))
                .body("handle", equalTo(handle))
                .body("bio", equalTo("Builds AR memory trails for searchable profile tests"))
                .body("locationLabel", equalTo("Bandung"))
                .body("viewerIsUser", equalTo(false));

        given()
                .when()
                .get("/social/search?viewerId=user_current&q={query}&types=users&limit=20", handle)
                .then()
                .statusCode(200)
                .body("results.find { it.resultType == 'user' && it.id == '%s' }.title".formatted(userId),
                        equalTo("Lens Maker " + suffix))
                .body("results.find { it.resultType == 'user' && it.id == '%s' }.subtitle".formatted(userId),
                        equalTo("@" + handle));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "handle": "%s",
                          "displayName": "Duplicate Handle"
                        }
                        """.formatted(duplicateUserId, handle))
                .when()
                .put("/social/users/{userId}/profile", duplicateUserId)
                .then()
                .statusCode(409);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "user_current",
                          "displayName": "Unauthorized"
                        }
                        """)
                .when()
                .put("/social/users/{userId}/profile", userId)
                .then()
                .statusCode(403);
    }

}
