package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphNode;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphRepositoryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialGraphEndpointReadModelTest {
    private static final Instant NOW = Instant.parse("2026-06-06T09:00:00Z");

    @Test
    void normalizesGraphNetworkAndNeighborhoodRequests() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("user_a", "friend_a", NOW);
        repository.saveFriendship("friend_a", "candidate_a", NOW.plusSeconds(1));
        repository.saveCloseFriend("user_a", "friend_a", NOW.plusSeconds(2));
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_a", "sibling", NOW.plusSeconds(3)));
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", NOW));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "owner", NOW));
        repository.saveGroupMembership(new MembershipRecord("circle_a", "group_a", "member", NOW));
        SocialGraphEndpointReadModel readModel = readModel(repository);

        SocialGraphResponse graph = readModel.graph("user_a");
        SocialNetworkResponse network = readModel.network("user_a", null);
        SocialNeighborhoodSummaryResponse neighborhood = readModel.neighborhood("user_a", null, null);
        SocialGraphRepositoryResponse repositoryStatus = readModel.repositoryStatus();

        assertEquals("user_a", graph.userId());
        assertEquals(1, graph.friendCount());
        assertEquals(1, graph.closeFriendCount());
        assertEquals(1, graph.friendOfFriendCount());
        assertEquals(1, graph.familyCount());
        assertEquals(1, graph.groupCount());
        assertEquals(2, network.maxDepth());
        assertEquals("friend_of_friend", node(network, "candidate_a").relation());
        assertEquals(2, node(network, "candidate_a").depth());
        assertEquals(2, neighborhood.maxDepth());
        assertEquals(4, neighborhood.visibleUserCount());
        assertEquals("friend_a", neighborhood.topConnectors().getFirst().userId());
        assertEquals("memory", repositoryStatus.backend());
        assertTrue(repositoryStatus.ready());
        assertEquals("memory", repositoryStatus.database());
    }

    @Test
    void normalizesConnectionPathRequests() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("user_a", "bridge_a", NOW);
        repository.saveFriendship("bridge_a", "target_a", NOW.plusSeconds(1));
        SocialGraphEndpointReadModel readModel = readModel(repository);

        SocialConnectionPathResponse path = readModel.connectionPath("user_a", "target_a", null);

        assertTrue(path.found());
        assertEquals(3, path.maxDepth());
        assertEquals(2, path.depth());
        assertEquals("connected", path.relation());
        assertEquals("bridge_a", path.nodes().get(1).id());
    }

    @Test
    void validatesGraphEndpointInputsAndBounds() {
        SocialGraphEndpointReadModel readModel = readModel(new InMemorySocialGraphRepository());

        assertThrows(BadRequestException.class, () -> readModel.graph(""));
        assertThrows(BadRequestException.class, () -> readModel.network("user_a", 4));
        assertThrows(BadRequestException.class, () -> readModel.neighborhood("user_a", 4, 10));
        assertThrows(BadRequestException.class, () -> readModel.neighborhood("user_a", 2, 26));
        assertThrows(BadRequestException.class, () -> readModel.connectionPath("", "target_a", null));
        assertThrows(BadRequestException.class, () -> readModel.connectionPath("user_a", "target_a", 5));
    }

    private SocialGraphEndpointReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        return new SocialGraphEndpointReadModel(
                repository,
                new SocialGraphSummaryReadModel(repository, relationshipPolicy),
                new SocialGraphProjectionPlanner(repository, userId -> "Label " + userId),
                new SocialGraphEndpointReadModel.Limits(3, 3, 25, 4));
    }

    private SocialGraphNode node(SocialNetworkResponse network, String nodeId) {
        return network.nodes().stream()
                .filter(node -> node.id().equals(nodeId))
                .findFirst()
                .orElseThrow();
    }
}
