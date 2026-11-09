package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipContextResolverTest {
    private final SocialRelationshipContextResolver resolver = new SocialRelationshipContextResolver();

    @Test
    void resolvesSelfBlockedAndPublicRelationships() {
        SocialRelationshipContextResponse self = resolve(signals(
                "viewer",
                "viewer",
                false,
                false,
                false,
                false,
                false,
                "",
                "",
                List.of(),
                List.of(),
                List.of()));
        SocialRelationshipContextResponse blocked = resolve(signals(
                "viewer",
                "owner",
                true,
                true,
                true,
                true,
                true,
                "sibling",
                "pending_incoming",
                List.of("mutual"),
                List.of("group"),
                List.of("community")));
        SocialRelationshipContextResponse publicContext = resolve(signals(
                "viewer",
                "owner",
                false,
                false,
                false,
                false,
                false,
                "",
                "",
                List.of(),
                List.of(),
                List.of()));

        assertEquals("self", self.relation());
        assertEquals(0, self.connectionDepth());
        assertEquals(100.0, self.affinityScore());
        assertEquals("blocked", blocked.relation());
        assertEquals(-1, blocked.connectionDepth());
        assertEquals(0.0, blocked.affinityScore());
        assertEquals("public", publicContext.relation());
        assertEquals(-1, publicContext.connectionDepth());
        assertEquals(0.0, publicContext.affinityScore());
    }

    @Test
    void resolvesDirectFriendCloseFriendFamilyPendingAndConnectedSignals() {
        SocialRelationshipContextResponse closeFriend = resolve(signals(
                "viewer",
                "owner",
                false,
                true,
                true,
                true,
                false,
                "",
                "",
                List.of(),
                List.of(),
                List.of()));
        SocialRelationshipContextResponse family = resolve(signals(
                "viewer",
                "owner",
                false,
                false,
                false,
                false,
                true,
                "sibling",
                "",
                List.of(),
                List.of(),
                List.of()));
        SocialRelationshipContextResponse pending = resolve(signals(
                "viewer",
                "owner",
                false,
                false,
                false,
                false,
                false,
                "",
                "pending_outgoing",
                List.of(),
                List.of(),
                List.of()));
        SocialRelationshipContextResponse connected = resolve(signals(
                "viewer",
                "owner",
                false,
                false,
                false,
                false,
                false,
                "",
                "",
                List.of("mutual_a", "mutual_b"),
                List.of("group_a"),
                List.of("community_a")));

        assertEquals("close_friend", closeFriend.relation());
        assertEquals(1, closeFriend.connectionDepth());
        assertEquals(85.0, closeFriend.affinityScore());
        assertTrue(closeFriend.directFriend());
        assertTrue(closeFriend.viewerMarkedCloseFriend());
        assertTrue(closeFriend.ownerMarkedCloseFriend());
        assertEquals("family", family.relation());
        assertEquals(1, family.connectionDepth());
        assertEquals(25.0, family.affinityScore());
        assertTrue(family.familyLink());
        assertEquals("sibling", family.familyRelationship());
        assertEquals("pending_outgoing", pending.relation());
        assertEquals(1, pending.connectionDepth());
        assertEquals(8.0, pending.affinityScore());
        assertEquals("connected", connected.relation());
        assertEquals(2, connected.connectionDepth());
        assertEquals(19.0, connected.affinityScore());
        assertEquals(2, connected.mutualFriendCount());
        assertEquals(1, connected.sharedGroupCount());
        assertEquals(1, connected.sharedCommunityCount());
        assertFalse(connected.blocked());
    }

    @Test
    void capsAffinityScoreAtOneHundred() {
        SocialRelationshipContextResponse context = resolve(signals(
                "viewer",
                "owner",
                false,
                true,
                true,
                true,
                true,
                "sibling",
                "pending_incoming",
                List.of("m1", "m2", "m3", "m4", "m5", "m6"),
                List.of("g1", "g2", "g3", "g4", "g5"),
                List.of("c1", "c2", "c3", "c4", "c5")));

        assertEquals(100.0, context.affinityScore());
    }

    private SocialRelationshipContextResponse resolve(SocialRelationshipContextResolver.Signals signals) {
        return resolver.resolve(signals, new VisibilityDecision(
                signals.viewerId(),
                signals.ownerId(),
                "public",
                true,
                true,
                false,
                false,
                "public"));
    }

    private SocialRelationshipContextResolver.Signals signals(
            String viewerId,
            String ownerId,
            boolean blocked,
            boolean directFriend,
            boolean viewerMarkedCloseFriend,
            boolean ownerMarkedCloseFriend,
            boolean familyLink,
            String familyRelationship,
            String pendingRequestDirection,
            List<String> mutualFriendIds,
            List<String> sharedGroupIds,
            List<String> sharedCommunityIds) {
        return new SocialRelationshipContextResolver.Signals(
                viewerId,
                ownerId,
                blocked,
                directFriend,
                viewerMarkedCloseFriend,
                ownerMarkedCloseFriend,
                familyLink,
                familyRelationship,
                pendingRequestDirection,
                mutualFriendIds,
                sharedGroupIds,
                sharedCommunityIds);
    }
}
