package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphNode;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialNetworkProjectionReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    @Test
    void projectsUserCircleNodesAndRelationshipEdges() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialNetworkProjectionReadModel readModel = new SocialNetworkProjectionReadModel(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveCloseFriend("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_a", "sibling", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "owner", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "public", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));

        SocialNetworkResponse network = readModel.network("user_a", 2);

        assertEquals("user_a", network.userId());
        assertEquals(2, network.maxDepth());
        assertEquals(1, network.friendCount());
        assertEquals(1, network.friendOfFriendCount());
        assertEquals(1, network.familyCount());
        assertEquals(1, network.groupCount());
        assertEquals(1, network.communityCount());
        assertEquals("friend_of_friend", node(network, "candidate").relation());
        assertEquals(2, node(network, "candidate").depth());
        assertEquals("Group A", node(network, "group_a").label());
        assertEquals("Community A", node(network, "community_a").label());
        assertEquals(List.of("family", "friend", "friend", "member_of", "member_of"), network.edges().stream()
                .map(edge -> edge.edgeType())
                .toList());
    }

    @Test
    void respectsMaxDepthAndHidesBlockedConnections() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialNetworkProjectionReadModel readModel = new SocialNetworkProjectionReadModel(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "candidate", BASE_TIME);
        repository.saveFriendship("bridge", "blocked_candidate", BASE_TIME);
        repository.saveFriendship("user_a", "blocked_direct", BASE_TIME);
        repository.saveBlock(new BlockRecord("user_a", "blocked_candidate", "", BASE_TIME));
        repository.saveBlock(new BlockRecord("user_a", "blocked_direct", "", BASE_TIME));

        SocialNetworkResponse firstHopOnly = readModel.network("user_a", 1);
        SocialNetworkResponse secondHop = readModel.network("user_a", 2);

        assertEquals(1, firstHopOnly.friendOfFriendCount());
        assertEquals(List.of("user_a", "bridge"), firstHopOnly.nodes().stream()
                .map(SocialGraphNode::id)
                .toList());
        assertEquals(1, secondHop.friendOfFriendCount());
        assertEquals(List.of("user_a", "bridge", "candidate"), secondHop.nodes().stream()
                .map(SocialGraphNode::id)
                .toList());
    }

    private SocialGraphNode node(SocialNetworkResponse network, String nodeId) {
        return network.nodes().stream()
                .filter(node -> node.id().equals(nodeId))
                .findFirst()
                .orElseThrow();
    }
}
