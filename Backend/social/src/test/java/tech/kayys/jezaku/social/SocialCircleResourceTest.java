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
 * Exercises circle HTTP endpoints for groups, communities, memberships, moderation, and ownership.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialCircleResourceTest extends SocialResourceHttpTestSupport {
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
    void supportsGroupAndCommunityContentTimelines() {
        String suffix = UUID.randomUUID().toString();
        String groupContentId = "circle_group_" + suffix;
        String communityContentId = "circle_community_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Circle group source"
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
                          "contentType": "post",
                          "scope": "community",
                          "targetId": "community_bandung_campus",
                          "caption": "Circle community source"
                        }
                        """.formatted(communityContentId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/social/groups/group_rooftop_creators/content?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("targetId", equalTo("group_rooftop_creators"))
                .body("targetType", equalTo("group"))
                .body("name", equalTo("Rooftop Creators"))
                .body("viewerId", equalTo("user_lens"))
                .body("viewerMember", equalTo(true))
                .body("items.contentId", hasItem(groupContentId))
                .body("items.contentId", not(hasItem(communityContentId)))
                .body("items.find { it.contentId == '%s' }.audience.reason".formatted(groupContentId),
                        equalTo("group_member"));

        given()
                .when()
                .get("/social/groups/group_rooftop_creators/content?viewerId=user_guardian&limit=50")
                .then()
                .statusCode(200)
                .body("viewerMember", equalTo(false))
                .body("items.contentId", not(hasItem(groupContentId)));

        given()
                .when()
                .get("/social/communities/community_bandung_campus/content?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("targetId", equalTo("community_bandung_campus"))
                .body("targetType", equalTo("community"))
                .body("name", equalTo("Bandung Campus"))
                .body("viewerId", equalTo("user_lens"))
                .body("viewerMember", equalTo(true))
                .body("items.contentId", hasItem(communityContentId))
                .body("items.contentId", not(hasItem(groupContentId)))
                .body("items.find { it.contentId == '%s' }.audience.reason".formatted(communityContentId),
                        equalTo("community_member"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens",
                          "reason": "not_today"
                        }
                        """)
                .when()
                .put("/social/content/{contentId}/hides", groupContentId)
                .then()
                .statusCode(200);

        given()
                .when()
                .get("/social/groups/group_rooftop_creators/content?viewerId=user_lens&limit=50")
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(groupContentId)));
    }

    @Test
    void supportsCircleContentModerationRemoveAndRestore() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String groupId = "moderation_group_" + suffix;
        String groupOwnerId = "moderation_owner_" + suffix;
        String groupAdminId = "moderation_admin_" + suffix;
        String groupMemberId = "moderation_member_" + suffix;
        String groupContentId = "moderation_group_content_" + suffix;
        String communityId = "moderation_community_" + suffix;
        String communityOwnerId = "moderation_community_owner_" + suffix;
        String communityMemberId = "moderation_community_member_" + suffix;
        String communityContentId = "moderation_community_content_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Moderation Group %s",
                          "visibility": "private",
                          "ownerId": "%s"
                        }
                        """.formatted(groupId, suffix, groupOwnerId))
                .when()
                .post("/social/groups")
                .then()
                .statusCode(201);

        given()
                .queryParam("actorUserId", groupOwnerId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "admin"
                        }
                        """.formatted(groupAdminId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200);

        given()
                .queryParam("actorUserId", groupAdminId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(groupMemberId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "%s",
                          "contentType": "post",
                          "scope": "group",
                          "targetId": "%s",
                          "caption": "Circle moderation candidate #%s"
                        }
                        """.formatted(groupContentId, groupMemberId, groupId, suffix))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .when()
                .get("/social/groups/{groupId}/content?viewerId={viewerId}&limit=20", groupId, groupAdminId)
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(groupContentId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "action": "remove",
                          "reason": "off topic"
                        }
                        """.formatted(groupMemberId))
                .when()
                .put("/social/groups/{groupId}/content/{contentId}/moderation", groupId, groupContentId)
                .then()
                .statusCode(403);

        String moderationId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "action": "remove",
                          "reason": "off topic"
                        }
                        """.formatted(groupAdminId))
                .when()
                .put("/social/groups/{groupId}/content/{contentId}/moderation", groupId, groupContentId)
                .then()
                .statusCode(200)
                .body("contentId", equalTo(groupContentId))
                .body("targetId", equalTo(groupId))
                .body("targetType", equalTo("group"))
                .body("actorUserId", equalTo(groupAdminId))
                .body("action", equalTo("remove"))
                .body("status", equalTo("removed"))
                .body("reason", equalTo("off topic"))
                .extract()
                .path("moderationId");

        given()
                .when()
                .get("/social/groups/{groupId}/content?viewerId={viewerId}&limit=20", groupId, groupAdminId)
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(groupContentId)));

        given()
                .when()
                .get("/social/groups/{groupId}/content-moderation?actorUserId={actorUserId}&status=removed",
                        groupId,
                        groupOwnerId)
                .then()
                .statusCode(200)
                .body("targetId", equalTo(groupId))
                .body("targetType", equalTo("group"))
                .body("records.moderationId", hasItem(moderationId));

        given()
                .when()
                .get("/social/content/{contentId}?viewerId={viewerId}", groupContentId, groupMemberId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "viewerId": "%s",
                          "contentIds": ["%s"]
                        }
                        """.formatted(groupMemberId, groupContentId))
                .when()
                .post("/social/content/access")
                .then()
                .statusCode(200)
                .body("hiddenContentIds", hasItem(groupContentId))
                .body("decisions.find { it.contentId == '%s' }.reason".formatted(groupContentId),
                        equalTo("circle_moderated"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "action": "restore",
                          "reason": "resolved"
                        }
                        """.formatted(groupOwnerId))
                .when()
                .put("/social/groups/{groupId}/content/{contentId}/moderation", groupId, groupContentId)
                .then()
                .statusCode(200)
                .body("action", equalTo("restore"))
                .body("status", equalTo("restored"));

        given()
                .when()
                .get("/social/groups/{groupId}/content?viewerId={viewerId}&limit=20", groupId, groupMemberId)
                .then()
                .statusCode(200)
                .body("items.contentId", hasItem(groupContentId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Moderation Community %s",
                          "visibility": "private",
                          "ownerId": "%s"
                        }
                        """.formatted(communityId, suffix, communityOwnerId))
                .when()
                .post("/social/communities")
                .then()
                .statusCode(201);

        given()
                .queryParam("actorUserId", communityOwnerId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(communityMemberId))
                .when()
                .put("/social/communities/{communityId}/members", communityId)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "%s",
                          "contentType": "post",
                          "scope": "community",
                          "targetId": "%s",
                          "caption": "Community moderation candidate"
                        }
                        """.formatted(communityContentId, communityMemberId, communityId))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "action": "remove",
                          "reason": "community cleanup"
                        }
                        """.formatted(communityOwnerId))
                .when()
                .put("/social/communities/{communityId}/content/{contentId}/moderation",
                        communityId,
                        communityContentId)
                .then()
                .statusCode(200)
                .body("targetType", equalTo("community"))
                .body("status", equalTo("removed"));

        given()
                .when()
                .get("/social/communities/{communityId}/content?viewerId={viewerId}&limit=20",
                        communityId,
                        communityMemberId)
                .then()
                .statusCode(200)
                .body("items.contentId", not(hasItem(communityContentId)));
    }

    @Test
    void supportsPublicCircleJoinAndLeave() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String publicGroupId = "join_group_" + suffix;
        String privateGroupId = "join_private_group_" + suffix;
        String publicCommunityId = "join_community_" + suffix;
        String privateCommunityId = "join_private_community_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Join Group %s",
                          "visibility": "public",
                          "ownerId": "user_current"
                        }
                        """.formatted(publicGroupId, suffix))
                .when()
                .post("/social/groups")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Private Join Group %s",
                          "visibility": "private",
                          "ownerId": "user_current"
                        }
                        """.formatted(privateGroupId, suffix))
                .when()
                .post("/social/groups")
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
                .put("/social/groups/{groupId}/join", publicGroupId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo("user_lens"))
                .body("targetId", equalTo(publicGroupId))
                .body("targetType", equalTo("group"))
                .body("role", equalTo("member"));

        given()
                .when()
                .get("/social/users/user_lens/groups")
                .then()
                .statusCode(200)
                .body("memberships.targetId", hasItem(publicGroupId));

        given()
                .when()
                .delete("/social/groups/{groupId}/leave/{userId}", publicGroupId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .delete("/social/groups/{groupId}/leave/{userId}", publicGroupId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/users/user_lens/groups")
                .then()
                .statusCode(200)
                .body("memberships.targetId", not(hasItem(publicGroupId)));

        given()
                .when()
                .delete("/social/groups/{groupId}/leave/{userId}", publicGroupId, "user_current")
                .then()
                .statusCode(409);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/join", privateGroupId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Join Community %s",
                          "visibility": "public",
                          "ownerId": "user_current"
                        }
                        """.formatted(publicCommunityId, suffix))
                .when()
                .post("/social/communities")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Private Join Community %s",
                          "visibility": "invite_only",
                          "ownerId": "user_current"
                        }
                        """.formatted(privateCommunityId, suffix))
                .when()
                .post("/social/communities")
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
                .put("/social/communities/{communityId}/join", publicCommunityId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo("user_lens"))
                .body("targetId", equalTo(publicCommunityId))
                .body("targetType", equalTo("community"))
                .body("role", equalTo("member"));

        given()
                .when()
                .get("/social/users/user_lens/communities")
                .then()
                .statusCode(200)
                .body("memberships.targetId", hasItem(publicCommunityId));

        given()
                .when()
                .delete("/social/communities/{communityId}/leave/{userId}", publicCommunityId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .delete("/social/communities/{communityId}/leave/{userId}", publicCommunityId, "user_lens")
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/users/user_lens/communities")
                .then()
                .statusCode(200)
                .body("memberships.targetId", not(hasItem(publicCommunityId)));

        given()
                .when()
                .delete("/social/communities/{communityId}/leave/{userId}", publicCommunityId, "user_current")
                .then()
                .statusCode(409);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/communities/{communityId}/join", privateCommunityId)
                .then()
                .statusCode(403);
    }

    @Test
    void supportsPrivateCircleRequestsAndInvites() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String privateGroupId = "request_group_" + suffix;
        String inviteCommunityId = "invite_community_" + suffix;
        String requestUserId = "request_user_" + suffix;
        String inviteUserId = "invite_user_" + suffix;
        String declineUserId = "decline_user_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Request Group %s",
                          "visibility": "private",
                          "ownerId": "user_current"
                        }
                        """.formatted(privateGroupId, suffix))
                .when()
                .post("/social/groups")
                .then()
                .statusCode(201);

        String joinRequestId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "message": "I would like to join"
                        }
                        """.formatted(requestUserId))
                .when()
                .post("/social/groups/{groupId}/join-requests", privateGroupId)
                .then()
                .statusCode(201)
                .body("targetId", equalTo(privateGroupId))
                .body("targetType", equalTo("group"))
                .body("userId", equalTo(requestUserId))
                .body("actorUserId", equalTo(requestUserId))
                .body("requestType", equalTo("join_request"))
                .body("status", equalTo("pending"))
                .extract()
                .path("requestId");

        given()
                .when()
                .get("/social/groups/{groupId}/join-requests?actorUserId=user_current&status=pending",
                        privateGroupId)
                .then()
                .statusCode(200)
                .body("targetId", equalTo(privateGroupId))
                .body("requestType", equalTo("join_request"))
                .body("requests.requestId", hasItem(joinRequestId));

        given()
                .when()
                .get("/social/users/{userId}/circle-join-requests?status=pending", requestUserId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(requestUserId))
                .body("requests.requestId", hasItem(joinRequestId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "user_lens",
                          "decision": "approve"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/join-requests/{requestId}/decision", privateGroupId, joinRequestId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "user_current",
                          "decision": "approve",
                          "message": "Welcome in"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/join-requests/{requestId}/decision", privateGroupId, joinRequestId)
                .then()
                .statusCode(200)
                .body("requestId", equalTo(joinRequestId))
                .body("status", equalTo("approved"));

        given()
                .when()
                .get("/social/users/{userId}/groups", requestUserId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", hasItem(privateGroupId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Invite Community %s",
                          "visibility": "invite_only",
                          "ownerId": "user_current"
                        }
                        """.formatted(inviteCommunityId, suffix))
                .when()
                .post("/social/communities")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "%s",
                          "message": "Can I join?"
                        }
                        """.formatted(inviteUserId))
                .when()
                .post("/social/communities/{communityId}/join-requests", inviteCommunityId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "inviterId": "user_lens",
                          "userId": "%s"
                        }
                        """.formatted(inviteUserId))
                .when()
                .post("/social/communities/{communityId}/invites", inviteCommunityId)
                .then()
                .statusCode(403);

        String inviteId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "inviterId": "user_current",
                          "userId": "%s",
                          "message": "Please join the circle"
                        }
                        """.formatted(inviteUserId))
                .when()
                .post("/social/communities/{communityId}/invites", inviteCommunityId)
                .then()
                .statusCode(201)
                .body("targetId", equalTo(inviteCommunityId))
                .body("targetType", equalTo("community"))
                .body("userId", equalTo(inviteUserId))
                .body("actorUserId", equalTo("user_current"))
                .body("requestType", equalTo("invite"))
                .body("status", equalTo("pending"))
                .extract()
                .path("requestId");

        given()
                .when()
                .get("/social/communities/{communityId}/invites?actorUserId=user_current&status=pending",
                        inviteCommunityId)
                .then()
                .statusCode(200)
                .body("requests.requestId", hasItem(inviteId));

        given()
                .when()
                .get("/social/users/{userId}/circle-invites?status=pending", inviteUserId)
                .then()
                .statusCode(200)
                .body("userId", equalTo(inviteUserId))
                .body("requests.requestId", hasItem(inviteId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "user_lens",
                          "decision": "accept"
                        }
                        """)
                .when()
                .put("/social/communities/{communityId}/invites/{requestId}/decision", inviteCommunityId, inviteId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "decision": "accept"
                        }
                        """.formatted(inviteUserId))
                .when()
                .put("/social/communities/{communityId}/invites/{requestId}/decision", inviteCommunityId, inviteId)
                .then()
                .statusCode(200)
                .body("requestId", equalTo(inviteId))
                .body("status", equalTo("accepted"));

        given()
                .when()
                .get("/social/users/{userId}/communities", inviteUserId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", hasItem(inviteCommunityId));

        String declinedInviteId = given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "inviterId": "user_current",
                          "userId": "%s",
                          "message": "Second invite"
                        }
                        """.formatted(declineUserId))
                .when()
                .post("/social/communities/{communityId}/invites", inviteCommunityId)
                .then()
                .statusCode(201)
                .extract()
                .path("requestId");

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "decision": "decline"
                        }
                        """.formatted(declineUserId))
                .when()
                .put("/social/communities/{communityId}/invites/{requestId}/decision",
                        inviteCommunityId,
                        declinedInviteId)
                .then()
                .statusCode(200)
                .body("status", equalTo("declined"));

        given()
                .when()
                .get("/social/users/{userId}/communities", declineUserId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", not(hasItem(inviteCommunityId)));
    }

    @Test
    void createsGroupsCommunitiesAndMemberships() {
        String ownerId = "circle_owner_" + UUID.randomUUID();
        String memberId = "circle_member_" + UUID.randomUUID();
        String groupId = "group_" + UUID.randomUUID();
        String communityId = "community_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Campus Runners",
                          "visibility": "public",
                          "ownerId": "%s"
                        }
                        """.formatted(groupId, ownerId))
                .when()
                .post("/social/groups")
                .then()
                .statusCode(201)
                .body("groupId", equalTo(groupId))
                .body("memberCount", equalTo(1));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(memberId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo(memberId))
                .body("targetId", equalTo(groupId))
                .body("targetType", equalTo("group"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "role": "admin"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/members/{memberId}/role", groupId, memberId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo(memberId))
                .body("targetId", equalTo(groupId))
                .body("role", equalTo("admin"));

        given()
                .when()
                .get("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200)
                .body("memberships.memberId", hasItem(ownerId))
                .body("memberships.memberId", hasItem(memberId));

        given()
                .when()
                .get("/social/users/{userId}/groups", memberId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", hasItem(groupId));

        given()
                .when()
                .delete("/social/groups/{groupId}/members/{memberId}", groupId, memberId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/users/{userId}/groups", memberId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", not(hasItem(groupId)));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Bandung Night Walk",
                          "visibility": "invite_only",
                          "ownerId": "%s"
                        }
                        """.formatted(communityId, ownerId))
                .when()
                .post("/social/communities")
                .then()
                .statusCode(201)
                .body("communityId", equalTo(communityId))
                .body("visibility", equalTo("invite_only"))
                .body("memberCount", equalTo(1));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "admin"
                        }
                        """.formatted(memberId))
                .when()
                .put("/social/communities/{communityId}/members", communityId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo(memberId))
                .body("targetId", equalTo(communityId))
                .body("targetType", equalTo("community"))
                .body("role", equalTo("admin"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "role": "member"
                        }
                        """)
                .when()
                .put("/social/communities/{communityId}/members/{memberId}/role", communityId, memberId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo(memberId))
                .body("targetId", equalTo(communityId))
                .body("role", equalTo("member"));

        given()
                .when()
                .get("/social/users/{userId}/communities", memberId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", hasItem(communityId));

        given()
                .when()
                .delete("/social/communities/{communityId}/members/{memberId}", communityId, memberId)
                .then()
                .statusCode(204);

        given()
                .when()
                .get("/social/users/{userId}/communities", memberId)
                .then()
                .statusCode(200)
                .body("memberships.targetId", not(hasItem(communityId)));
    }

    @Test
    void enforcesCircleRolePermissionsAndOwnershipTransfer() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String groupId = "perm_group_" + suffix;
        String groupOwnerId = "perm_group_owner_" + suffix;
        String groupAdminId = "perm_group_admin_" + suffix;
        String groupMemberId = "perm_group_member_" + suffix;
        String removedMemberId = "perm_group_removed_" + suffix;
        String communityId = "perm_community_" + suffix;
        String communityOwnerId = "perm_community_owner_" + suffix;
        String communityNewOwnerId = "perm_community_new_owner_" + suffix;
        String communityMemberId = "perm_community_member_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Permission Group %s",
                          "visibility": "private",
                          "ownerId": "%s"
                        }
                        """.formatted(groupId, suffix, groupOwnerId))
                .when()
                .post("/social/groups")
                .then()
                .statusCode(201);

        given()
                .queryParam("actorUserId", groupMemberId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(groupMemberId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(403);

        given()
                .queryParam("actorUserId", groupOwnerId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "admin"
                        }
                        """.formatted(groupAdminId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo(groupAdminId))
                .body("role", equalTo("admin"));

        given()
                .queryParam("actorUserId", groupAdminId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(groupMemberId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200)
                .body("memberId", equalTo(groupMemberId))
                .body("role", equalTo("member"));

        given()
                .queryParam("actorUserId", groupAdminId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "role": "admin"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/members/{memberId}/role", groupId, groupMemberId)
                .then()
                .statusCode(403);

        given()
                .queryParam("actorUserId", groupAdminId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(removedMemberId))
                .when()
                .put("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200);

        given()
                .queryParam("actorUserId", groupAdminId)
                .when()
                .delete("/social/groups/{groupId}/members/{memberId}", groupId, removedMemberId)
                .then()
                .statusCode(204);

        given()
                .queryParam("actorUserId", groupAdminId)
                .when()
                .delete("/social/groups/{groupId}/members/{memberId}", groupId, groupOwnerId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "newOwnerId": "%s"
                        }
                        """.formatted(groupOwnerId, groupAdminId))
                .when()
                .put("/social/groups/{groupId}/ownership-transfer", groupId)
                .then()
                .statusCode(200)
                .body("targetId", equalTo(groupId))
                .body("targetType", equalTo("group"))
                .body("previousOwnerId", equalTo(groupOwnerId))
                .body("newOwnerId", equalTo(groupAdminId))
                .body("previousOwnerRole", equalTo("admin"))
                .body("newOwnerRole", equalTo("owner"));

        given()
                .when()
                .get("/social/groups/{groupId}/members", groupId)
                .then()
                .statusCode(200)
                .body("memberships.find { it.memberId == '%s' }.role".formatted(groupOwnerId), equalTo("admin"))
                .body("memberships.find { it.memberId == '%s' }.role".formatted(groupAdminId), equalTo("owner"))
                .body("memberships.memberId", not(hasItem(removedMemberId)));

        given()
                .queryParam("actorUserId", groupOwnerId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "role": "admin"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/members/{memberId}/role", groupId, groupAdminId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Permission Community %s",
                          "visibility": "invite_only",
                          "ownerId": "%s"
                        }
                        """.formatted(communityId, suffix, communityOwnerId))
                .when()
                .post("/social/communities")
                .then()
                .statusCode(201);

        given()
                .queryParam("actorUserId", communityOwnerId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(communityNewOwnerId))
                .when()
                .put("/social/communities/{communityId}/members", communityId)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "newOwnerId": "%s"
                        }
                        """.formatted(communityOwnerId, communityNewOwnerId))
                .when()
                .put("/social/communities/{communityId}/ownership-transfer", communityId)
                .then()
                .statusCode(200)
                .body("targetType", equalTo("community"))
                .body("previousOwnerRole", equalTo("admin"))
                .body("newOwnerRole", equalTo("owner"));

        given()
                .queryParam("actorUserId", communityOwnerId)
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "memberId": "%s",
                          "role": "member"
                        }
                        """.formatted(communityMemberId))
                .when()
                .put("/social/communities/{communityId}/members", communityId)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "actorUserId": "%s",
                          "newOwnerId": "%s"
                        }
                        """.formatted(communityOwnerId, communityMemberId))
                .when()
                .put("/social/communities/{communityId}/ownership-transfer", communityId)
                .then()
                .statusCode(403);

        given()
                .when()
                .get("/social/communities/{communityId}/members", communityId)
                .then()
                .statusCode(200)
                .body("memberships.find { it.memberId == '%s' }.role".formatted(communityOwnerId), equalTo("admin"))
                .body("memberships.find { it.memberId == '%s' }.role".formatted(communityNewOwnerId), equalTo("owner"));
    }

    @Test
    void protectsLastCircleOwner() {
        String ownerId = "last_owner_" + UUID.randomUUID();
        String groupId = "group_last_owner_" + UUID.randomUUID();
        String communityId = "community_last_owner_" + UUID.randomUUID();

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "groupId": "%s",
                          "name": "Solo Group",
                          "visibility": "private",
                          "ownerId": "%s"
                        }
                        """.formatted(groupId, ownerId))
                .when()
                .post("/social/groups")
                .then()
                .statusCode(201);

        given()
                .when()
                .delete("/social/groups/{groupId}/members/{memberId}", groupId, ownerId)
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "role": "member"
                        }
                        """)
                .when()
                .put("/social/groups/{groupId}/members/{memberId}/role", groupId, ownerId)
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "communityId": "%s",
                          "name": "Solo Community",
                          "visibility": "private",
                          "ownerId": "%s"
                        }
                        """.formatted(communityId, ownerId))
                .when()
                .post("/social/communities")
                .then()
                .statusCode(201);

        given()
                .when()
                .delete("/social/communities/{communityId}/members/{memberId}", communityId, ownerId)
                .then()
                .statusCode(409)
                .body("code", equalTo("CONFLICT"));
    }
}
