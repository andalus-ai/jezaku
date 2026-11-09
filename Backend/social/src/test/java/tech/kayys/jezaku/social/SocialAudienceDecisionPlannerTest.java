package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
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

class SocialAudienceDecisionPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T05:00:00Z");

    @Test
    void resolvesDirectRelationshipScopesAndBlockedPrecedence() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Access access = new Access();
        SocialAudienceDecisionPlanner planner = new SocialAudienceDecisionPlanner(repository, access);
        access.put("owner", "friend", context("owner", "friend", "friend", false, true, true, false, false));
        access.put("owner", "family", context("owner", "family", "family", false, false, false, false, true));
        access.put("owner", "blocked", context("owner", "blocked", "blocked", true, false, false, false, false));

        SocialAudienceDecisionResponse owner = planner.decision("owner", "owner", "private", "");
        SocialAudienceDecisionResponse friend = planner.decision("owner", "friend", "friends", "");
        SocialAudienceDecisionResponse closeFriend = planner.decision("owner", "friend", "close_friends", "");
        SocialAudienceDecisionResponse notCloseFriend = planner.decision("owner", "family", "close_friends", "");
        SocialAudienceDecisionResponse family = planner.decision("owner", "family", "family", "");
        SocialAudienceDecisionResponse blocked = planner.decision("owner", "blocked", "public", "");

        assertTrue(owner.canView());
        assertEquals("owner", owner.reason());
        assertTrue(owner.viewerIsOwner());
        assertTrue(friend.canView());
        assertEquals("friend", friend.reason());
        assertTrue(closeFriend.canView());
        assertEquals("close_friend", closeFriend.reason());
        assertFalse(notCloseFriend.canView());
        assertEquals("not_close_friend", notCloseFriend.reason());
        assertTrue(family.canView());
        assertEquals("family", family.reason());
        assertFalse(blocked.canView());
        assertEquals("blocked", blocked.reason());
        assertTrue(blocked.blocked());
    }

    @Test
    void resolvesCircleAudienceMembershipAndTargetState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_owner_missing", "Group Missing Owner", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_a", "Community A", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner", "group_a", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_owner_missing", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("owner", "community_a", "owner", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("viewer", "community_a", "member", BASE_TIME));
        SocialAudienceDecisionPlanner planner = new SocialAudienceDecisionPlanner(repository, new Access());

        SocialAudienceDecisionResponse ownerGroup = planner.decision("owner", "owner", "group", "group_a");
        SocialAudienceDecisionResponse groupAllowed = planner.decision("owner", "viewer", "group", "group_a");
        SocialAudienceDecisionResponse groupDenied = planner.decision("owner", "outsider", "group", "group_a");
        SocialAudienceDecisionResponse ownerMissing = planner.decision(
                "owner",
                "viewer",
                "group",
                "group_owner_missing");
        SocialAudienceDecisionResponse communityAllowed = planner.decision(
                "owner",
                "viewer",
                "community",
                "community_a");

        assertTrue(ownerGroup.canView());
        assertEquals("owner", ownerGroup.reason());
        assertEquals("group_a", ownerGroup.targetId());
        assertTrue(ownerGroup.targetRequired());
        assertTrue(ownerGroup.viewerTargetMember());
        assertTrue(groupAllowed.canView());
        assertEquals("group_member", groupAllowed.reason());
        assertTrue(groupAllowed.targetRequired());
        assertTrue(groupAllowed.viewerTargetMember());
        assertFalse(groupDenied.canView());
        assertEquals("not_group_member", groupDenied.reason());
        assertFalse(groupDenied.viewerTargetMember());
        assertFalse(ownerMissing.canView());
        assertEquals("owner_not_group_member", ownerMissing.reason());
        assertTrue(communityAllowed.canView());
        assertEquals("community_member", communityAllowed.reason());
    }

    @Test
    void rejectsUnsupportedScopesAndMissingTargets() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialAudienceDecisionPlanner planner = new SocialAudienceDecisionPlanner(repository, new Access());

        assertThrows(BadRequestException.class, () -> planner.decision("owner", "viewer", "followers", ""));
        assertThrows(BadRequestException.class, () -> planner.decision("owner", "viewer", "group", ""));
        assertThrows(NotFoundException.class, () -> planner.decision("owner", "viewer", "group", "missing_group"));
    }

    private static SocialRelationshipContextResponse context(
            String ownerId,
            String viewerId,
            String relation,
            boolean blocked,
            boolean directFriend,
            boolean viewerMarkedCloseFriend,
            boolean ownerMarkedCloseFriend,
            boolean familyLink) {
        return new SocialRelationshipContextResponse(
                ownerId,
                viewerId,
                relation,
                blocked ? -1 : directFriend || familyLink ? 1 : -1,
                blocked ? 0.0 : directFriend ? 70.0 : familyLink ? 25.0 : 0.0,
                blocked,
                directFriend,
                viewerMarkedCloseFriend,
                ownerMarkedCloseFriend,
                familyLink,
                familyLink ? "sibling" : "",
                "",
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                new VisibilityDecision(
                        ownerId,
                        viewerId,
                        relation,
                        !blocked,
                        !blocked,
                        !blocked,
                        false,
                        relation));
    }

    private static final class Access implements SocialAudienceDecisionPlanner.Access {
        private final Map<String, SocialRelationshipContextResponse> contexts = new HashMap<>();

        private void put(String ownerId, String viewerId, SocialRelationshipContextResponse context) {
            contexts.put(key(ownerId, viewerId), context);
        }

        @Override
        public SocialRelationshipContextResponse relationshipContext(String ownerId, String viewerId) {
            return contexts.getOrDefault(
                    key(ownerId, viewerId),
                    context(ownerId, viewerId, "public", false, false, false, false, false));
        }

        private String key(String ownerId, String viewerId) {
            return ownerId + "->" + viewerId;
        }
    }
}
