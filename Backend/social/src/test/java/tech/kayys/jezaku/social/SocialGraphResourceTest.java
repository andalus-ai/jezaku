package tech.kayys.jezaku.social;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;

/**
 * Exercises graph, audience, recommendation, context, and visibility HTTP endpoints.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialGraphResourceTest extends SocialResourceHttpTestSupport {
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
    void returnsSeededFriendGraphAndVisibility() {
        given()
                .when()
                .get("/social/graph/user_current")
                .then()
                .statusCode(200)
                .body("friendCount", greaterThanOrEqualTo(1))
                .body("closeFriendCount", greaterThanOrEqualTo(1))
                .body("friendOfFriendCount", greaterThanOrEqualTo(2))
                .body("familyCount", greaterThanOrEqualTo(1))
                .body("groupCount", greaterThanOrEqualTo(1))
                .body("communityCount", greaterThanOrEqualTo(1))
                .body("incomingRequestCount", greaterThanOrEqualTo(1))
                .body("blockedCount", greaterThanOrEqualTo(1));

        given()
                .when()
                .get("/social/visibility?viewerId=user_rooftop&ownerId=user_current")
                .then()
                .statusCode(200)
                .body("relation", equalTo("close_friend"))
                .body("canSeeLocation", equalTo(true))
                .body("canInteract", equalTo(true));
    }

    @Test
    void returnsSeededSocialNetworkProjection() {
        given()
                .when()
                .get("/social/network/user_current?maxDepth=2")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("maxDepth", equalTo(2))
                .body("friendCount", greaterThanOrEqualTo(1))
                .body("friendOfFriendCount", greaterThanOrEqualTo(2))
                .body("familyCount", greaterThanOrEqualTo(1))
                .body("groupCount", greaterThanOrEqualTo(1))
                .body("communityCount", greaterThanOrEqualTo(1))
                .body("nodes.find { it.id == 'user_current' }.nodeType", equalTo("user"))
                .body("nodes.find { it.id == 'user_current' }.relation", equalTo("self"))
                .body("nodes.find { it.id == 'user_rooftop' }.relation", equalTo("close_friend"))
                .body("nodes.find { it.id == 'user_lens' }.relation", equalTo("friend_of_friend"))
                .body("nodes.find { it.id == 'user_guardian' }.relation", equalTo("family"))
                .body("nodes.find { it.id == 'group_rooftop_creators' }.nodeType", equalTo("group"))
                .body("nodes.find { it.id == 'community_bandung_campus' }.nodeType", equalTo("community"))
                .body("edges.find { it.fromId == 'user_current' && it.toId == 'user_rooftop' }.edgeType",
                        equalTo("friend"))
                .body("edges.find { it.fromId == 'user_rooftop' && it.toId == 'user_lens' }.relation",
                        equalTo("friend_of_friend"))
                .body("edges.find { it.fromId == 'user_current' && it.toId == 'user_guardian' }.edgeType",
                        equalTo("family"))
                .body("edges.find { it.fromId == 'user_current' && it.toId == 'group_rooftop_creators' }.edgeType",
                        equalTo("member_of"))
                .body("edges.find { it.fromId == 'user_current' && it.toId == 'community_bandung_campus' }.edgeType",
                        equalTo("member_of"));
    }

    @Test
    void returnsSeededNeighborhoodSummary() {
        given()
                .when()
                .get("/social/neighborhood/user_current?maxDepth=2&limit=2")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("maxDepth", equalTo(2))
                .body("visibleUserCount", greaterThanOrEqualTo(4))
                .body("directFriendCount", greaterThanOrEqualTo(1))
                .body("closeFriendCount", greaterThanOrEqualTo(1))
                .body("familyCount", greaterThanOrEqualTo(1))
                .body("friendOfFriendCount", greaterThanOrEqualTo(2))
                .body("sharedCircleUserCount", greaterThanOrEqualTo(3))
                .body("blockedHiddenCount", greaterThanOrEqualTo(1))
                .body("buckets.find { it.relation == 'close_friend' }.userIds", hasItem("user_rooftop"))
                .body("buckets.find { it.relation == 'family' }.userIds", hasItem("user_guardian"))
                .body("buckets.find { it.relation == 'friend_of_friend' }.userIds", hasItem("user_lens"))
                .body("buckets.find { it.relation == 'shared_group' }.userIds", hasItem("user_lens"))
                .body("topConnectors.find { it.userId == 'user_rooftop' }.relation", equalTo("close_friend"))
                .body("topConnectors.find { it.userId == 'user_rooftop' }.introducedUserCount",
                        greaterThanOrEqualTo(2))
                .body("topConnectors.find { it.userId == 'user_rooftop' }.sharedGroupCount",
                        greaterThanOrEqualTo(1))
                .body("circles.targetId", hasItem("group_rooftop_creators"))
                .body("circles.targetId", hasItem("community_bandung_campus"));
    }

    @Test
    void returnsAudiencePreviewsForGraphScopes() {
        given()
                .when()
                .get("/social/audience/preview?ownerId=user_current&scope=friends")
                .then()
                .statusCode(200)
                .body("ownerId", equalTo("user_current"))
                .body("scope", equalTo("friends"))
                .body("enumerable", equalTo(true))
                .body("includedCount", greaterThanOrEqualTo(1))
                .body("includedUserIds", hasItem("user_rooftop"))
                .body("buckets.find { it.relation == 'close_friend' }.userIds", hasItem("user_rooftop"));

        given()
                .when()
                .get("/social/audience/preview?ownerId=user_current&scope=close_friends")
                .then()
                .statusCode(200)
                .body("scope", equalTo("close_friends"))
                .body("includedUserIds", hasItem("user_rooftop"))
                .body("returnedCount", greaterThanOrEqualTo(1));

        given()
                .when()
                .get("/social/audience/preview?ownerId=user_current&scope=family")
                .then()
                .statusCode(200)
                .body("scope", equalTo("family"))
                .body("includedUserIds", hasItem("user_guardian"))
                .body("buckets.find { it.relation == 'family' }.userIds", hasItem("user_guardian"));

        given()
                .when()
                .get("/social/audience/preview?ownerId=user_current&scope=group&targetId=group_rooftop_creators")
                .then()
                .statusCode(200)
                .body("scope", equalTo("group"))
                .body("targetId", equalTo("group_rooftop_creators"))
                .body("includedUserIds", hasItem("user_rooftop"))
                .body("includedUserIds", hasItem("user_lens"))
                .body("buckets.find { it.relation == 'connected' }.userIds", hasItem("user_lens"));

        given()
                .when()
                .get("/social/audience/preview?ownerId=user_current&scope=public")
                .then()
                .statusCode(200)
                .body("scope", equalTo("public"))
                .body("enumerable", equalTo(false))
                .body("includedCount", equalTo(0))
                .body("excludedBlockedCount", greaterThanOrEqualTo(1));
    }

    @Test
    void returnsAudienceDecisionsForGraphScopes() {
        given()
                .when()
                .get("/social/audience/decision?ownerId=user_current&viewerId=user_rooftop&scope=friends")
                .then()
                .statusCode(200)
                .body("canView", equalTo(true))
                .body("reason", equalTo("friend"))
                .body("targetRequired", equalTo(false));

        given()
                .when()
                .get("/social/audience/decision?ownerId=user_current&viewerId=user_rooftop&scope=close_friends")
                .then()
                .statusCode(200)
                .body("canView", equalTo(true))
                .body("reason", equalTo("close_friend"));

        given()
                .when()
                .get("/social/audience/decision?ownerId=user_current&viewerId=user_lens&scope=close_friends")
                .then()
                .statusCode(200)
                .body("canView", equalTo(false))
                .body("reason", equalTo("not_close_friend"));

        given()
                .when()
                .get("/social/audience/decision?ownerId=user_current&viewerId=user_guardian&scope=family")
                .then()
                .statusCode(200)
                .body("canView", equalTo(true))
                .body("reason", equalTo("family"));

        given()
                .when()
                .get("/social/audience/decision?ownerId=user_current&viewerId=user_lens&scope=group&targetId=group_rooftop_creators")
                .then()
                .statusCode(200)
                .body("canView", equalTo(true))
                .body("reason", equalTo("group_member"))
                .body("targetRequired", equalTo(true))
                .body("viewerTargetMember", equalTo(true));

        given()
                .when()
                .get("/social/audience/decision?ownerId=user_current&viewerId=user_blocked&scope=public")
                .then()
                .statusCode(200)
                .body("canView", equalTo(false))
                .body("reason", equalTo("blocked"))
                .body("blocked", equalTo(true));
    }

    @Test
    void returnsBatchAudienceDecisions() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "ownerId": "user_current",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "viewerIds": ["user_rooftop", "user_lens", "user_blocked", "user_lens"]
                        }
                        """)
                .when()
                .post("/social/audience/decision/batch")
                .then()
                .statusCode(200)
                .body("ownerId", equalTo("user_current"))
                .body("scope", equalTo("group"))
                .body("targetId", equalTo("group_rooftop_creators"))
                .body("count", equalTo(3))
                .body("decisions", hasSize(3))
                .body("decisions.find { it.viewerId == 'user_rooftop' }.canView", equalTo(true))
                .body("decisions.find { it.viewerId == 'user_rooftop' }.reason", equalTo("group_member"))
                .body("decisions.find { it.viewerId == 'user_lens' }.canView", equalTo(true))
                .body("decisions.find { it.viewerId == 'user_lens' }.viewerTargetMember", equalTo(true))
                .body("decisions.find { it.viewerId == 'user_blocked' }.canView", equalTo(false))
                .body("decisions.find { it.viewerId == 'user_blocked' }.reason", equalTo("blocked"));
    }

    @Test
    void returnsAudienceAccessForCandidateOwners() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "viewerId": "user_current",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "ownerIds": ["user_rooftop", "user_lens", "user_blocked", "user_lens"]
                        }
                        """)
                .when()
                .post("/social/audience/access")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("scope", equalTo("group"))
                .body("targetId", equalTo("group_rooftop_creators"))
                .body("count", equalTo(3))
                .body("allowedCount", equalTo(2))
                .body("deniedCount", equalTo(1))
                .body("allowedOwnerIds", hasItem("user_rooftop"))
                .body("allowedOwnerIds", hasItem("user_lens"))
                .body("deniedOwnerIds", hasItem("user_blocked"))
                .body("decisions.find { it.ownerId == 'user_rooftop' }.canView", equalTo(true))
                .body("decisions.find { it.ownerId == 'user_lens' }.reason", equalTo("group_member"))
                .body("decisions.find { it.ownerId == 'user_blocked' }.canView", equalTo(false))
                .body("decisions.find { it.ownerId == 'user_blocked' }.reason", equalTo("blocked"));
    }

    @Test
    void returnsGraphRepositoryStatus() {
        given()
                .when()
                .get("/social/graph/repository")
                .then()
                .statusCode(200)
                .body("backend", equalTo("memory"))
                .body("ready", equalTo(true))
                .body("database", equalTo("memory"))
                .body("schemaBootstrapEnabled", equalTo(false));
    }

    @Test
    void returnsSeededFriendRecommendations() {
        given()
                .when()
                .get("/social/recommendations/user_current?limit=2")
                .then()
                .statusCode(200)
                .body("userId", equalTo("user_current"))
                .body("limit", equalTo(2))
                .body("count", equalTo(2))
                .body("hasMore", equalTo(true))
                .body("nextCursor", not(equalTo("")))
                .body("recommendations.userId", hasItem("user_lens"))
                .body("recommendations.userId", hasItem("user_maker"))
                .body("recommendations.userId", not(hasItem("user_rooftop")))
                .body("recommendations.find { it.userId == 'user_lens' }.profile.displayName",
                        equalTo("Lens Friend"))
                .body("recommendations.find { it.userId == 'user_lens' }.profile.profileVisible",
                        equalTo(true))
                .body("recommendations.find { it.userId == 'user_lens' }.reason", equalTo("mutual_friends"))
                .body("recommendations.find { it.userId == 'user_lens' }.mutualFriendCount",
                        greaterThanOrEqualTo(1))
                .body("recommendations.find { it.userId == 'user_lens' }.sharedGroupCount",
                        greaterThanOrEqualTo(1))
                .body("recommendations.find { it.userId == 'user_lens' }.sharedCommunityCount",
                        greaterThanOrEqualTo(1))
                .body("recommendations.find { it.userId == 'user_lens' }.mutualFriendIds",
                        hasItem("user_rooftop"))
                .body("recommendations.find { it.userId == 'user_lens' }.mutualFriends.userId",
                        hasItem("user_rooftop"))
                .body("recommendations.find { it.userId == 'user_lens' }.sharedGroups.targetId",
                        hasItem("group_rooftop_creators"))
                .body("recommendations.find { it.userId == 'user_lens' }.sharedCommunities.targetId",
                        hasItem("community_bandung_campus"));
    }

    @Test
    void returnsRelationshipContextSignals() {
        given()
                .when()
                .get("/social/relationships/context?viewerId=user_current&ownerId=user_lens")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("ownerId", equalTo("user_lens"))
                .body("relation", equalTo("connected"))
                .body("connectionDepth", equalTo(2))
                .body("affinityScore", greaterThan(0.0f))
                .body("blocked", equalTo(false))
                .body("directFriend", equalTo(false))
                .body("mutualFriendCount", greaterThanOrEqualTo(1))
                .body("sharedGroupCount", greaterThanOrEqualTo(1))
                .body("sharedCommunityCount", greaterThanOrEqualTo(1))
                .body("mutualFriendIds", hasItem("user_rooftop"))
                .body("sharedGroupIds", hasItem("group_rooftop_creators"))
                .body("sharedCommunityIds", hasItem("community_bandung_campus"))
                .body("visibility.relation", equalTo("public"));

        given()
                .when()
                .get("/social/relationships/context?viewerId=user_rooftop&ownerId=user_current")
                .then()
                .statusCode(200)
                .body("relation", equalTo("close_friend"))
                .body("connectionDepth", equalTo(1))
                .body("directFriend", equalTo(true))
                .body("ownerMarkedCloseFriend", equalTo(true))
                .body("visibility.relation", equalTo("close_friend"))
                .body("visibility.canSeeLocation", equalTo(true));

        given()
                .when()
                .get("/social/relationships/context?viewerId=user_blocked&ownerId=user_current")
                .then()
                .statusCode(200)
                .body("relation", equalTo("blocked"))
                .body("connectionDepth", equalTo(-1))
                .body("affinityScore", equalTo(0.0f))
                .body("blocked", equalTo(true))
                .body("visibility.canViewProfile", equalTo(false));
    }

    @Test
    void returnsBatchRelationshipContextSignals() {
        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "viewerId": "user_current",
                          "ownerIds": ["user_rooftop", "user_lens", "user_blocked", "user_lens"]
                        }
                        """)
                .when()
                .post("/social/relationships/context/batch")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_current"))
                .body("count", equalTo(3))
                .body("contexts.ownerId", hasItem("user_rooftop"))
                .body("contexts.ownerId", hasItem("user_lens"))
                .body("contexts.ownerId", hasItem("user_blocked"))
                .body("contexts.find { it.ownerId == 'user_rooftop' }.relation", equalTo("friend"))
                .body("contexts.find { it.ownerId == 'user_lens' }.relation", equalTo("connected"))
                .body("contexts.find { it.ownerId == 'user_lens' }.mutualFriendIds", hasItem("user_rooftop"))
                .body("contexts.find { it.ownerId == 'user_blocked' }.relation", equalTo("blocked"))
                .body("contexts.find { it.ownerId == 'user_blocked' }.visibility.canViewProfile", equalTo(false));
    }

    @Test
    void returnsExplainableConnectionPaths() {
        given()
                .when()
                .get("/social/relationships/path?fromUserId=user_current&toUserId=user_lens&maxDepth=3")
                .then()
                .statusCode(200)
                .body("fromUserId", equalTo("user_current"))
                .body("toUserId", equalTo("user_lens"))
                .body("found", equalTo(true))
                .body("depth", equalTo(1))
                .body("relation", equalTo("shared_group"))
                .body("nodes.id", hasItem("user_current"))
                .body("nodes.id", hasItem("user_lens"))
                .body("edges.find { it.toId == 'user_lens' }.edgeType", equalTo("shared_group"))
                .body("edges.find { it.toId == 'user_lens' }.relation", equalTo("group_rooftop_creators"));

        given()
                .when()
                .get("/social/relationships/path?fromUserId=user_blocked&toUserId=user_current&maxDepth=3")
                .then()
                .statusCode(200)
                .body("found", equalTo(false))
                .body("depth", equalTo(-1))
                .body("relation", equalTo("blocked"));

        given()
                .when()
                .get("/social/relationships/path?fromUserId=user_current&toUserId=user_unknown&maxDepth=2")
                .then()
                .statusCode(200)
                .body("found", equalTo(false))
                .body("depth", equalTo(-1))
                .body("relation", equalTo("not_connected"));
    }

}
