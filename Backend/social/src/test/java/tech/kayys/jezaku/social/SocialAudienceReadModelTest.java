package tech.kayys.jezaku.social;

import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialAudienceReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T10:00:00Z");

    @Test
    void assemblesBatchDecisionsWithDeduplicatedViewerIds() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer_allowed", "group_a", "member", BASE_TIME));
        SocialAudienceReadModel readModel = readModel(repository, new Access());

        SocialAudienceDecisionBatchResponse response = readModel.decisions(new SocialAudienceDecisionBatchRequest(
                "owner",
                "group",
                "group_a",
                List.of("viewer_allowed", "viewer_denied", "viewer_allowed")));

        assertEquals("owner", response.ownerId());
        assertEquals("group", response.scope());
        assertEquals("group_a", response.targetId());
        assertEquals(2, response.count());
        assertTrue(response.decisions().stream()
                .filter(decision -> decision.viewerId().equals("viewer_allowed"))
                .findFirst()
                .orElseThrow()
                .canView());
        assertEquals("not_group_member", response.decisions().stream()
                .filter(decision -> decision.viewerId().equals("viewer_denied"))
                .findFirst()
                .orElseThrow()
                .reason());
    }

    @Test
    void assemblesAccessBucketsFromOwnerDecisions() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Access access = new Access();
        access.put("owner_friend", "viewer", context("owner_friend", "viewer", "friend", true));
        access.put("owner_public", "viewer", context("owner_public", "viewer", "public", false));
        SocialAudienceReadModel readModel = readModel(repository, access);

        SocialAudienceAccessResponse response = readModel.access(new SocialAudienceAccessRequest(
                "viewer",
                "friends",
                "",
                List.of("owner_friend", "owner_public", "owner_friend")));

        assertEquals("viewer", response.viewerId());
        assertEquals("friends", response.scope());
        assertEquals(2, response.count());
        assertEquals(1, response.allowedCount());
        assertEquals(1, response.deniedCount());
        assertEquals(List.of("owner_friend"), response.allowedOwnerIds());
        assertEquals(List.of("owner_public"), response.deniedOwnerIds());
        assertTrue(response.decisions().getFirst().canView());
        assertFalse(response.decisions().getLast().canView());
    }

    @Test
    void validatesCirclePreviewTargetsBeforeDelegating() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_a", "member", BASE_TIME));
        SocialAudienceReadModel readModel = readModel(repository, new Access());

        SocialAudiencePreviewResponse response = readModel.preview("owner", "group", "group_a", 1);

        assertEquals("owner", response.ownerId());
        assertEquals("group", response.scope());
        assertEquals("group_a", response.targetId());
        assertEquals(1, response.returnedCount());
        assertEquals(List.of("member_a"), response.includedUserIds());
        assertThrows(NotFoundException.class, () -> readModel.preview("owner", "group", "missing_group", 1));
    }

    private SocialAudienceReadModel readModel(InMemorySocialGraphRepository repository, Access access) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialAudiencePreviewReadModel previewReadModel = new SocialAudiencePreviewReadModel(
                repository,
                relationshipPolicy,
                new SocialCircleMembershipIndex(repository),
                access::relationshipContext);
        return new SocialAudienceReadModel(
                repository,
                previewReadModel,
                new SocialAudienceDecisionPlanner(repository, access),
                5,
                3,
                3);
    }

    private static SocialRelationshipContextResponse context(
            String ownerId,
            String viewerId,
            String relation,
            boolean directFriend) {
        return new SocialRelationshipContextResponse(
                ownerId,
                viewerId,
                relation,
                "public".equals(relation) ? -1 : 1,
                directFriend ? 70.0 : 0.0,
                false,
                directFriend,
                false,
                false,
                false,
                "",
                "",
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                new VisibilityDecision(ownerId, viewerId, relation, true, false, true, true, relation));
    }

    private static final class Access implements SocialAudienceDecisionPlanner.Access {
        private final Map<String, SocialRelationshipContextResponse> contexts = new HashMap<>();

        private void put(String ownerId, String viewerId, SocialRelationshipContextResponse context) {
            contexts.put(ownerId + "->" + viewerId, context);
        }

        @Override
        public SocialRelationshipContextResponse relationshipContext(String ownerId, String viewerId) {
            return contexts.getOrDefault(
                    ownerId + "->" + viewerId,
                    context(ownerId, viewerId, "public", false));
        }
    }
}
