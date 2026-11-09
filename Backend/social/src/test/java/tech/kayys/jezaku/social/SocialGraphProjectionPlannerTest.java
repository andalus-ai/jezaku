package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphNode;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialGraphProjectionPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    @Test
    void projectsNetworkAndNeighborhoodFromGraphSignals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialGraphProjectionPlanner planner = new SocialGraphProjectionPlanner(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveCloseFriend("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_a", "sibling", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("circle_candidate", "group_a", "member", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "public", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("circle_candidate", "community_a", "member", BASE_TIME));

        SocialNetworkResponse network = planner.network("user_a", 2);
        SocialNeighborhoodSummaryResponse neighborhood = planner.neighborhood("user_a", 2, 1);

        assertEquals("user_a", network.userId());
        assertEquals(1, network.friendCount());
        assertEquals(1, network.friendOfFriendCount());
        assertEquals(1, network.familyCount());
        assertEquals(1, network.groupCount());
        assertEquals(1, network.communityCount());
        assertEquals("friend_of_friend", node(network, "candidate").relation());
        assertEquals(2, node(network, "candidate").depth());
        assertEquals("Group A", node(network, "group_a").label());
        assertEquals("Community A", node(network, "community_a").label());

        assertEquals(4, neighborhood.visibleUserCount());
        assertEquals(1, neighborhood.directFriendCount());
        assertEquals(1, neighborhood.closeFriendCount());
        assertEquals(1, neighborhood.familyCount());
        assertEquals(1, neighborhood.friendOfFriendCount());
        assertEquals(1, neighborhood.sharedCircleUserCount());
        assertEquals(List.of("bridge"), bucketUsers(neighborhood, "close_friend"));
        assertEquals(List.of("candidate"), bucketUsers(neighborhood, "friend_of_friend"));
        assertEquals(List.of("family_a"), bucketUsers(neighborhood, "family"));
        assertEquals(List.of("circle_candidate"), bucketUsers(neighborhood, "shared_group"));
        assertEquals("bridge", neighborhood.topConnectors().getFirst().userId());
        assertEquals(1, neighborhood.topConnectors().getFirst().introducedUserCount());
        assertEquals(List.of("community_a", "group_a"), neighborhood.circles().stream()
                .map(circle -> circle.targetId())
                .toList());
    }

    @Test
    void findsExplainableFriendPathAndStopsOnBlocks() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialGraphProjectionPlanner planner = new SocialGraphProjectionPlanner(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "path_candidate", BASE_TIME);
        repository.saveFriendship("user_a", "blocked_candidate", BASE_TIME);
        repository.saveBlock(new BlockRecord("user_a", "blocked_candidate", "", BASE_TIME));

        SocialConnectionPathResponse path = planner.connectionPath("user_a", "path_candidate", 3);
        SocialConnectionPathResponse blocked = planner.connectionPath("user_a", "blocked_candidate", 3);

        assertTrue(path.found());
        assertEquals(2, path.depth());
        assertEquals("connected", path.relation());
        assertEquals(List.of("user_a", "bridge", "path_candidate"), path.nodes().stream()
                .map(SocialGraphNode::id)
                .toList());
        assertFalse(blocked.found());
        assertEquals(-1, blocked.depth());
        assertEquals("blocked", blocked.relation());
    }

    private SocialGraphNode node(SocialNetworkResponse network, String nodeId) {
        return network.nodes().stream()
                .filter(node -> node.id().equals(nodeId))
                .findFirst()
                .orElseThrow();
    }

    private List<String> bucketUsers(SocialNeighborhoodSummaryResponse neighborhood, String relation) {
        return neighborhood.buckets().stream()
                .filter(bucket -> bucket.relation().equals(relation))
                .findFirst()
                .orElseThrow()
                .userIds();
    }
}
