package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphEdge;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphNode;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialConnectionPathReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    @Test
    void findsFriendPathWithStableConnectorNodes() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialConnectionPathReadModel readModel = new SocialConnectionPathReadModel(
                repository,
                userId -> "Label " + userId);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "target", BASE_TIME);

        SocialConnectionPathResponse path = readModel.path("user_a", "target", 3);

        assertTrue(path.found());
        assertEquals(2, path.depth());
        assertEquals("connected", path.relation());
        assertEquals(List.of("user_a", "bridge", "target"), path.nodes().stream()
                .map(SocialGraphNode::id)
                .toList());
        assertEquals(List.of("friend", "friend"), path.edges().stream()
                .map(SocialGraphEdge::edgeType)
                .toList());
    }

    @Test
    void usesSharedCircleEdgesAndHidesBlockedTargets() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialConnectionPathReadModel readModel = new SocialConnectionPathReadModel(
                repository,
                userId -> "Label " + userId);
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("target", "group_a", "member", BASE_TIME.plusSeconds(60)));
        repository.saveGroupMembership(new MembershipRecord("blocked_target", "group_a", "member", BASE_TIME.plusSeconds(120)));
        repository.saveBlock(new BlockRecord("user_a", "blocked_target", "", BASE_TIME));

        SocialConnectionPathResponse sharedGroupPath = readModel.path("user_a", "target", 2);
        SocialConnectionPathResponse blocked = readModel.path("user_a", "blocked_target", 2);

        assertTrue(sharedGroupPath.found());
        assertEquals(1, sharedGroupPath.depth());
        assertEquals("shared_group", sharedGroupPath.relation());
        assertEquals(List.of("shared_group"), sharedGroupPath.edges().stream()
                .map(SocialGraphEdge::edgeType)
                .toList());
        assertFalse(blocked.found());
        assertEquals("blocked", blocked.relation());
    }
}
