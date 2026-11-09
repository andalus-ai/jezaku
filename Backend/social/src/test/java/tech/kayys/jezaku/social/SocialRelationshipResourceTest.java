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
 * Exercises relationship HTTP endpoints for follows, mutes, blocks, family, friends, and close friends.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialRelationshipResourceTest extends SocialResourceHttpTestSupport {
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
    void emitsFriendRequestActivitiesAcrossHttpWorkflow() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String senderId = "friend_sender_" + suffix;
        String recipientId = "friend_recipient_" + suffix;

        Response created = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "fromUserId": "%s",
                          "toUserId": "%s",
                          "message": "connect?"
                        }
                        """.formatted(senderId, recipientId))
                .when()
                .post("/social/friend-requests")
                .then()
                .statusCode(201)
                .body("fromUserId", equalTo(senderId))
                .body("toUserId", equalTo(recipientId))
                .body("status", equalTo("pending"))
                .extract()
                .response();

        given()
                .when()
                .get("/social/activity/{userId}?mode=inbox&limit=20", recipientId)
                .then()
                .statusCode(200)
                .body("activities.find { it.actorId == '%s' && it.eventType == 'friend_request_received' }.recipientId"
                        .formatted(senderId), equalTo(recipientId))
                .body("activities.find { it.actorId == '%s' && it.eventType == 'friend_request_received' }.message"
                        .formatted(senderId), equalTo(senderId + " sent you a friend request."));

        String requestId = created.path("id");
        given()
                .when()
                .post("/social/friend-requests/{requestId}/accept?actorUserId={actorUserId}",
                        requestId,
                        recipientId)
                .then()
                .statusCode(200)
                .body("status", equalTo("accepted"));

        given()
                .when()
                .get("/social/activity/{userId}?mode=inbox&limit=20", senderId)
                .then()
                .statusCode(200)
                .body("activities.find { it.actorId == '%s' && it.eventType == 'friend_request_accepted' }.recipientId"
                        .formatted(recipientId), equalTo(senderId))
                .body("activities.find { it.actorId == '%s' && it.eventType == 'friend_request_accepted' }.message"
                        .formatted(recipientId), equalTo(recipientId + " accepted your friend request."));
    }

    @Test
    void supportsPersonalMutesAcrossDiscoverySurfaces() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String userTag = "muteuser" + suffix;
        String groupTag = "mutegroup" + suffix;
        String userContentId = "mute_user_content_" + suffix;
        String groupContentId = "mute_group_content_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "public",
                          "caption": "Personal mute public source #%s"
                        }
                        """.formatted(userContentId, userTag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("tags", hasItem(userTag));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_rooftop",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Personal mute group source #%s"
                        }
                        """.formatted(groupContentId, groupTag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201)
                .body("tags", hasItem(groupTag));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/tags/{tag}/follows", userTag)
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
                .put("/social/tags/{tag}/follows", groupTag)
                .then()
                .statusCode(200);

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=100")
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(userContentId))
                .body("items.contentId", hasItem(groupContentId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens",
                          "targetType": "user",
                          "targetId": "user_current",
                          "reason": "too many posts"
                        }
                        """)
                .when()
                .put("/social/mutes")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("targetType", equalTo("user"))
                .body("targetId", equalTo("user_current"));

        given()
                .when()
                .get("/social/users/user_lens/mutes?targetType=user&limit=10")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("targetType", equalTo("user"))
                .body("count", greaterThanOrEqualTo(1))
                .body("mutes.targetId", hasItem("user_current"));

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=100")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(userContentId)))
                .body("items.contentId", hasItem(groupContentId));

        given()
                .when()
                .get("/social/search?viewerId=user_lens&q={query}&types=content&limit=20", userTag)
                .then()
                .statusCode(200)
                .body("results.id", not(hasItem(userContentId)));

        given()
                .when()
                .get("/social/tags/{tag}/content?viewerId=user_lens&limit=20", userTag)
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(userContentId)));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens",
                          "targetType": "group",
                          "targetId": "group_rooftop_creators",
                          "reason": "pause this circle"
                        }
                        """)
                .when()
                .put("/social/mutes")
                .then()
                .statusCode(200)
                .body("targetType", equalTo("group"))
                .body("targetId", equalTo("group_rooftop_creators"));

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=100")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(userContentId)))
                .body("items.contentId", not(hasItem(groupContentId)));

        given()
                .when()
                .get("/social/search?viewerId=user_lens&q=rooftop&types=groups&limit=20")
                .then()
                .statusCode(200)
                .body("results.id", not(hasItem("group_rooftop_creators")));

        given()
                .when()
                .get("/social/users/user_lens/topic-feed?limit=20")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(userContentId)))
                .body("items.contentId", not(hasItem(groupContentId)));

        given()
                .when()
                .delete("/social/mutes/{userId}/{targetType}/{targetId}", "user_lens", "user", "user_current")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=100")
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(userContentId))
                .body("items.contentId", not(hasItem(groupContentId)));

        given()
                .when()
                .delete("/social/mutes/{userId}/{targetType}/{targetId}",
                        "user_lens", "group", "group_rooftop_creators")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/feed?viewerId=user_lens&limit=100")
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(userContentId))
                .body("items.contentId", hasItem(groupContentId));
    }

    @Test
    void supportsUserFollowsAndFollowingFeed() {
        String suffix = UUID.randomUUID().toString();
        String groupContentId = "follow_group_" + suffix;
        String privateContentId = "follow_private_" + suffix;
        String publicContentId = "follow_public_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_lens",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Follow-visible post"
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
                          "caption": "Follow-hidden post"
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
                          "ownerId": "user_lens",
                          "contentType": "post",
                          "scope": "public",
                          "caption": "Second follow-visible post"
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
                          "followerId": "user_current"
                        }
                        """)
                .when()
                .put("/social/users/{followedUserId}/followers", "user_lens")
                .then()
                .statusCode(200)
                .body("followerId", equalTo("user_current"))
                .body("followedUserId", equalTo("user_lens"))
                .body("status", equalTo("following"));

        given()
                .when()
                .get("/social/users/user_lens/followers")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_lens"))
                .body("direction", equalTo("followers"))
                .body("follows.find { it.followerId == 'user_current' }.followedUserId", equalTo("user_lens"));

        given()
                .when()
                .get("/social/users/user_current/following")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("direction", equalTo("following"))
                .body("follows.find { it.followedUserId == 'user_lens' }.followerId", equalTo("user_current"));

        given()
                .when()
                .get("/social/users/user_current/following-feed?limit=50")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", hasItem(publicContentId))
                .body("items.contentId", not(hasItem(privateContentId)))
                .body("items.find { it.contentId == '%s' }.ownerId".formatted(groupContentId), equalTo("user_lens"));

        Response firstFollowingPage = given()
                .when()
                .get("/social/users/user_current/following-feed?limit=1")
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("hasMore", equalTo(true))
                .body("nextCursor", not(equalTo("")))
                .extract()
                .response();
        String firstFollowingContentId = firstFollowingPage.path("items[0].contentId");
        String nextFollowingCursor = firstFollowingPage.path("nextCursor");

        given()
                .when()
                .get("/social/users/user_current/following-feed?limit=1&cursor={cursor}", nextFollowingCursor)
                .then()
                .statusCode(200)
                .body("count", equalTo(1))
                .body("items.contentId", not(hasItem(firstFollowingContentId)));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "followerId": "user_blocked"
                        }
                        """)
                .when()
                .put("/social/users/{followedUserId}/followers", "user_current")
                .then()
                .statusCode(409);

        given()
                .when()
                .delete("/social/users/{followedUserId}/followers/{followerId}", "user_lens", "user_current")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/users/user_current/following")
                .then()
                .statusCode(200)
                .body("follows.followedUserId", not(hasItem("user_lens")));
    }

    @Test
    void createsAndListsFamilyLinks() {
        String firstUserId = "family_first_" + UUID.randomUUID();
        String secondUserId = "family_second_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "firstUserId": "%s",
                          "secondUserId": "%s",
                          "relationship": "sibling"
                        }
                        """.formatted(firstUserId, secondUserId))
                .when()
                .put("/social/family")
                .then()
                .statusCode(200)
                .body("firstUserId", equalTo(firstUserId))
                .body("secondUserId", equalTo(secondUserId))
                .body("relationship", equalTo("sibling"));

        given()
                .when()
                .get("/social/family/{userId}", firstUserId)
                .then()
                .statusCode(200)
                .body("links.secondUserId", hasItem(secondUserId))
                .body("links.relationship", hasItem("sibling"));

        given()
                .when()
                .delete("/social/family/{userId}/{relativeId}", firstUserId, secondUserId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/family/{userId}", firstUserId)
                .then()
                .statusCode(200)
                .body("links.secondUserId", not(hasItem(secondUserId)));
    }

    @Test
    void createsAndAcceptsFriendRequest() {
        String fromUserId = "from_" + UUID.randomUUID();
        String toUserId = "to_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "displayName": "Friend Request Sender",
                          "avatarUrl": "https://cdn.jezaku.test/avatars/friend-sender.png",
                          "profileVisibility": "public"
                        }
                        """.formatted(fromUserId))
                .when()
                .put("/social/users/{userId}/profile", fromUserId)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "displayName": "Friend Request Recipient",
                          "avatarUrl": "https://cdn.jezaku.test/avatars/friend-recipient.png",
                          "profileVisibility": "public"
                        }
                        """.formatted(toUserId))
                .when()
                .put("/social/users/{userId}/profile", toUserId)
                .then()
                .statusCode(200);

        String requestId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "fromUserId": "%s",
                          "toUserId": "%s",
                          "message": "Let us connect for a campus trail."
                        }
                        """.formatted(fromUserId, toUserId))
                .when()
                .post("/social/friend-requests")
                .then()
                .statusCode(201)
                .body("fromUserId", equalTo(fromUserId))
                .body("toUserId", equalTo(toUserId))
                .body("status", equalTo("pending"))
                .body("fromUser.displayName", equalTo("Friend Request Sender"))
                .body("fromUser.profileVisible", equalTo(true))
                .body("toUser.displayName", equalTo("Friend Request Recipient"))
                .body("toUser.profileVisible", equalTo(true))
                .extract()
                .path("id");

        given()
                .when()
                .get("/social/friend-requests/{userId}?direction=incoming", toUserId)
                .then()
                .statusCode(200)
                .body("direction", equalTo("incoming"))
                .body("status", equalTo("all"))
                .body("requests.id", hasItem(requestId))
                .body("requests.find { it.id == '%s' }.fromUser.displayName".formatted(requestId),
                        equalTo("Friend Request Sender"))
                .body("requests.find { it.id == '%s' }.toUser.displayName".formatted(requestId),
                        equalTo("Friend Request Recipient"));

        given()
                .when()
                .post("/social/friend-requests/{requestId}/accept?actorUserId={actorUserId}", requestId, toUserId)
                .then()
                .statusCode(200)
                .body("status", equalTo("accepted"))
                .body("fromUser.displayName", equalTo("Friend Request Sender"))
                .body("toUser.displayName", equalTo("Friend Request Recipient"));

        given()
                .when()
                .get("/social/friends/{userId}?viewerId={viewerId}", fromUserId, fromUserId)
                .then()
                .statusCode(200)
                .body("friends.userId", hasItem(toUserId))
                .body("friends.find { it.userId == '%s' }.friend.displayName".formatted(toUserId),
                        equalTo("Friend Request Recipient"))
                .body("friends.find { it.userId == '%s' }.friend.profileVisible".formatted(toUserId),
                        equalTo(true));

        given()
                .when()
                .get("/social/visibility?viewerId={viewerId}&ownerId={ownerId}", fromUserId, toUserId)
                .then()
                .statusCode(200)
                .body("relation", equalTo("friend"))
                .body("canSendFriendRequest", equalTo(false));
    }

    @Test
    void declinesFriendRequest() {
        String fromUserId = "decline_from_" + UUID.randomUUID();
        String toUserId = "decline_to_" + UUID.randomUUID();

        String requestId = given()
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

        given()
                .when()
                .post("/social/friend-requests/{requestId}/decline?actorUserId={actorUserId}", requestId, toUserId)
                .then()
                .statusCode(200)
                .body("status", equalTo("declined"));

        given()
                .when()
                .get("/social/visibility?viewerId={viewerId}&ownerId={ownerId}", fromUserId, toUserId)
                .then()
                .statusCode(200)
                .body("relation", equalTo("public"))
                .body("canSendFriendRequest", equalTo(true));
    }

    @Test
    void blockPreventsInteractionAndHidesVisibility() {
        String blocker = "blocker_" + UUID.randomUUID();
        String blocked = "blocked_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "blockedUserId": "%s",
                          "reason": "unsafe nearby behavior"
                        }
                        """.formatted(blocker, blocked))
                .when()
                .put("/social/blocks")
                .then()
                .statusCode(200)
                .body("userId", equalTo(blocker))
                .body("blockedUserId", equalTo(blocked));

        given()
                .when()
                .get("/social/visibility?viewerId={viewerId}&ownerId={ownerId}", blocked, blocker)
                .then()
                .statusCode(200)
                .body("relation", equalTo("blocked"))
                .body("canViewProfile", equalTo(false))
                .body("canSeeLocation", equalTo(false));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "fromUserId": "%s",
                          "toUserId": "%s"
                        }
                        """.formatted(blocked, blocker))
                .when()
                .post("/social/friend-requests")
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"))
                .body("status", equalTo(409))
                .body("path", equalTo("/social/friend-requests"));

        given()
                .when()
                .get("/social/blocks/{userId}", blocker)
                .then()
                .statusCode(200)
                .body("blocks.blockedUserId", hasItem(blocked));
    }

    @Test
    void managesCloseFriendsForExistingFriend() {
        String fromUserId = "close_from_" + UUID.randomUUID();
        String toUserId = "close_to_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "displayName": "Close Friend Target",
                          "profileVisibility": "public"
                        }
                        """.formatted(toUserId))
                .when()
                .put("/social/users/{userId}/profile", toUserId)
                .then()
                .statusCode(200);

        String requestId = createPendingRequest(fromUserId, toUserId);

        given()
                .when()
                .post("/social/friend-requests/{requestId}/accept?actorUserId={actorUserId}", requestId, toUserId)
                .then()
                .statusCode(200);

        given()
                .when()
                .put("/social/close-friends/{userId}/{friendId}", fromUserId, toUserId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(toUserId))
                .body("closeFriend", equalTo(true))
                .body("friend.displayName", equalTo("Close Friend Target"))
                .body("friend.profileVisible", equalTo(true));

        given()
                .when()
                .get("/social/close-friends/{userId}?viewerId={viewerId}", fromUserId, fromUserId)
                .then()
                .statusCode(200)
                .body("friends.userId", hasItem(toUserId))
                .body("friends.find { it.userId == '%s' }.friend.displayName".formatted(toUserId),
                        equalTo("Close Friend Target"));

        given()
                .when()
                .delete("/social/close-friends/{userId}/{friendId}", fromUserId, toUserId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/close-friends/{userId}", fromUserId)
                .then()
                .statusCode(200)
                .body("friends.userId", not(hasItem(toUserId)));
    }

    @Test
    void rejectsCloseFriendWhenUsersAreNotFriends() {
        given()
                .when()
                .put("/social/close-friends/not_friend_a/not_friend_b")
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"))
                .body("status", equalTo(409))
                .body("path", equalTo("/social/close-friends/not_friend_a/not_friend_b"));
    }

    @Test
    void removesFriendship() {
        String fromUserId = "remove_from_" + UUID.randomUUID();
        String toUserId = "remove_to_" + UUID.randomUUID();
        String requestId = createPendingRequest(fromUserId, toUserId);

        given()
                .when()
                .post("/social/friend-requests/{requestId}/accept?actorUserId={actorUserId}", requestId, toUserId)
                .then()
                .statusCode(200);

        given()
                .when()
                .delete("/social/friends/{userId}/{friendId}", fromUserId, toUserId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/friends/{userId}", fromUserId)
                .then()
                .statusCode(200)
                .body("friends.userId", not(hasItem(toUserId)))
                .body("friends", hasSize(0));
    }

    @Test
    void rejectsSelfFriendRequest() {
        given()
                .contentType(ContentType.JSON)
                .header("X-Request-Id", "social-self-request")
                .body("""
                        {
                          "fromUserId": "same_user",
                          "toUserId": "same_user"
                        }
                        """)
                .when()
                .post("/social/friend-requests")
                .then()
                .statusCode(400)
                .header("X-Request-Id", equalTo("social-self-request"))
                .body("code", equalTo("BAD_REQUEST"))
                .body("status", equalTo(400))
                .body("path", equalTo("/social/friend-requests"))
                .body("requestId", equalTo("social-self-request"));
    }

}
