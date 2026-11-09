package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipContextReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T12:00:00Z");

    @Test
    void assemblesConnectedContextFromMutualFriendsAndSharedCircles() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("viewer", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "owner", BASE_TIME.plusSeconds(1));
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("viewer", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("owner", "community_a", "member", BASE_TIME));
        SocialRelationshipContextReadModel readModel = readModel(repository);

        SocialRelationshipContextResponse response = readModel.context("viewer", "owner");

        assertEquals("connected", response.relation());
        assertEquals(2, response.connectionDepth());
        assertEquals(13.0, response.affinityScore());
        assertEquals(List.of("bridge"), response.mutualFriendIds());
        assertEquals(List.of("group_a"), response.sharedGroupIds());
        assertEquals(List.of("community_a"), response.sharedCommunityIds());
    }

    @Test
    void assemblesDirectFamilyAndPendingSignals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("viewer", "close_owner", BASE_TIME);
        repository.saveCloseFriend("close_owner", "viewer", BASE_TIME.plusSeconds(1));
        repository.saveFamilyLink(new FamilyLinkRecord("viewer", "relative", "sibling", BASE_TIME.plusSeconds(2)));
        repository.saveFriendRequest(new FriendRequestRecord(
                "request_1",
                "viewer",
                "pending_owner",
                "",
                "pending",
                BASE_TIME.plusSeconds(3),
                BASE_TIME.plusSeconds(3)));
        SocialRelationshipContextReadModel readModel = readModel(repository);

        SocialRelationshipContextResponse close = readModel.context("viewer", "close_owner");
        SocialRelationshipContextResponse family = readModel.context("viewer", "relative");
        SocialRelationshipContextResponse pending = readModel.context("viewer", "pending_owner");

        assertEquals("close_friend", close.relation());
        assertTrue(close.directFriend());
        assertFalse(close.viewerMarkedCloseFriend());
        assertTrue(close.ownerMarkedCloseFriend());
        assertEquals("family", family.relation());
        assertTrue(family.familyLink());
        assertEquals("sibling", family.familyRelationship());
        assertEquals("pending_outgoing", pending.relation());
        assertEquals(1, pending.connectionDepth());
    }

    @Test
    void batchesContextsWithDeduplicatedOwnersAndHidesBlockedSharedSignals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendship("viewer", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "blocked_owner", BASE_TIME.plusSeconds(1));
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("blocked_owner", "group_a", "member", BASE_TIME));
        repository.saveBlock(new BlockRecord("viewer", "blocked_owner", "", BASE_TIME.plusSeconds(2)));
        SocialRelationshipContextReadModel readModel = readModel(repository);

        SocialRelationshipContextBatchResponse response = readModel.contexts(new SocialRelationshipContextBatchRequest(
                "viewer",
                List.of("blocked_owner", "public_owner", "blocked_owner")));

        assertEquals("viewer", response.viewerId());
        assertEquals(2, response.count());
        SocialRelationshipContextResponse blocked = context(response, "blocked_owner");
        assertEquals("blocked", blocked.relation());
        assertEquals(-1, blocked.connectionDepth());
        assertEquals(List.of(), blocked.mutualFriendIds());
        assertEquals(List.of(), blocked.sharedGroupIds());
        assertEquals("public", context(response, "public_owner").relation());
    }

    private SocialRelationshipContextReadModel readModel(InMemorySocialGraphRepository repository) {
        return new SocialRelationshipContextReadModel(
                repository,
                new SocialRelationshipPolicy(repository),
                new SocialCircleMembershipIndex(repository),
                new SocialRelationshipContextResolver(),
                this::visibility,
                5);
    }

    private VisibilityDecision visibility(String viewerId, String ownerId) {
        return new VisibilityDecision(
                viewerId,
                ownerId,
                "public",
                true,
                true,
                true,
                false,
                "public");
    }

    private SocialRelationshipContextResponse context(
            SocialRelationshipContextBatchResponse response,
            String ownerId) {
        return response.contexts().stream()
                .filter(context -> context.ownerId().equals(ownerId))
                .findFirst()
                .orElseThrow();
    }
}
