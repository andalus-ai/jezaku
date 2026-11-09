package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialUserProfileSummaryResolverTest {
    private static final Instant NOW = Instant.parse("2026-06-03T21:00:00Z");

    @Test
    void summarizesVisibleProfileRelationshipAndGraphCounts() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialUserProfileRecord profile = profile("owner_a", "public");
        repository.saveUserProfile(profile);
        repository.saveFriendship("owner_a", "viewer_a", NOW.plusSeconds(1));
        repository.saveFriendship("owner_a", "friend_b", NOW.plusSeconds(2));
        repository.saveUserFollow(new SocialUserFollowRecord("viewer_a", "owner_a", NOW.plusSeconds(3)));
        repository.saveUserFollow(new SocialUserFollowRecord("follower_b", "owner_a", NOW.plusSeconds(4)));
        repository.saveUserFollow(new SocialUserFollowRecord("blocked_follower", "owner_a", NOW.plusSeconds(5)));
        repository.saveUserFollow(new SocialUserFollowRecord("owner_a", "following_a", NOW.plusSeconds(6)));
        repository.saveUserFollow(new SocialUserFollowRecord("owner_a", "blocked_following", NOW.plusSeconds(7)));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_a", "member", NOW.plusSeconds(8)));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_b", "admin", NOW.plusSeconds(9)));
        repository.saveCommunityMembership(new MembershipRecord("owner_a", "community_a", "member", NOW.plusSeconds(10)));
        repository.saveContent(content("content_public", "owner_a", "public"));
        repository.saveContent(content("content_private", "owner_a", "private"));
        repository.saveContent(content("hidden_content", "owner_a", "public"));
        Set<String> blockedPairs = Set.of(pair("owner_a", "blocked_follower"), pair("owner_a", "blocked_following"));
        SocialUserProfileSummaryResolver resolver = resolver(repository, blockedPairs, Set.of(pair("owner_a", "viewer_a")));

        SocialUserProfileSummaryResponse summary = resolver.summary("owner_a", "viewer_a");

        assertEquals("owner_a", summary.userId());
        assertEquals("viewer_a", summary.viewerId());
        assertEquals(profile.displayName(), summary.displayName());
        assertEquals(profile.bio(), summary.bio());
        assertEquals("direct_friend", summary.relation());
        assertFalse(summary.viewerIsUser());
        assertTrue(summary.viewerFollowsUser());
        assertEquals("following", summary.viewerFollowStatus());
        assertEquals(NOW.plusSeconds(3), summary.viewerFollowStatusUpdatedAt());
        assertTrue(summary.directFriend());
        assertFalse(summary.blocked());
        assertEquals(2, summary.friendCount());
        assertEquals(2, summary.followerCount());
        assertEquals(1, summary.followingCount());
        assertEquals(2, summary.groupCount());
        assertEquals(1, summary.communityCount());
        assertEquals(3, summary.authoredContentCount());
        assertEquals(2, summary.publicContentCount());
        assertEquals(2, summary.visibleContentCount());
    }

    @Test
    void hidesSensitiveFieldsAndCountsWhenBlocked() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("owner_a", "public"));
        repository.saveFriendship("owner_a", "friend_b", NOW.plusSeconds(1));
        repository.saveUserFollow(new SocialUserFollowRecord("viewer_a", "owner_a", NOW.plusSeconds(2)));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_a", "member", NOW.plusSeconds(3)));
        repository.saveContent(content("content_public", "owner_a", "public"));
        SocialUserProfileSummaryResolver resolver = resolver(
                repository,
                Set.of(pair("viewer_a", "owner_a")),
                Set.of());

        SocialUserProfileSummaryResponse summary = resolver.summary("owner_a", "viewer_a");

        assertEquals("", summary.bio());
        assertEquals("", summary.avatarUrl());
        assertEquals("", summary.websiteUrl());
        assertEquals("", summary.locationLabel());
        assertEquals("blocked", summary.viewerFollowStatus());
        assertFalse(summary.viewerFollowsUser());
        assertTrue(summary.blocked());
        assertEquals(0, summary.friendCount());
        assertEquals(0, summary.followerCount());
        assertEquals(0, summary.followingCount());
        assertEquals(0, summary.groupCount());
        assertEquals(0, summary.communityCount());
        assertEquals(0, summary.authoredContentCount());
        assertEquals(0, summary.publicContentCount());
        assertEquals(0, summary.visibleContentCount());
    }

    @Test
    void exposesPendingFollowStateForNonBlockedViewer() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserProfile(profile("owner_private", "private"));
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "viewer_a",
                "owner_private",
                "pending",
                NOW.plusSeconds(1),
                NOW.plusSeconds(2)));
        SocialUserProfileSummaryResolver resolver = resolver(repository, Set.of(), Set.of());

        SocialUserProfileSummaryResponse summary = resolver.summary("owner_private", "viewer_a");

        assertEquals("pending", summary.viewerFollowStatus());
        assertEquals(NOW.plusSeconds(2), summary.viewerFollowStatusUpdatedAt());
        assertFalse(summary.viewerFollowsUser());
        assertEquals("", summary.bio());
        assertFalse(summary.blocked());
    }

    private SocialUserProfileSummaryResolver resolver(
            InMemorySocialGraphRepository repository,
            Set<String> blockedPairs,
            Set<String> friendPairs) {
        SocialUserProfileResolver profileResolver = new SocialUserProfileResolver(
                repository,
                (firstUserId, secondUserId) -> blocked(blockedPairs, firstUserId, secondUserId),
                (firstUserId, secondUserId) -> friends(friendPairs, firstUserId, secondUserId));
        SocialUserStatsResolver statsResolver = new SocialUserStatsResolver(
                repository,
                this::audienceDecision,
                (contentId, userId) -> contentId.startsWith("hidden"),
                (firstUserId, secondUserId) -> blocked(blockedPairs, firstUserId, secondUserId));
        return new SocialUserProfileSummaryResolver(
                repository,
                profileResolver,
                statsResolver,
                (viewerId, ownerId) -> context(viewerId, ownerId, blockedPairs, friendPairs));
    }

    private SocialRelationshipContextResponse context(
            String viewerId,
            String ownerId,
            Set<String> blockedPairs,
            Set<String> friendPairs) {
        boolean blocked = blocked(blockedPairs, viewerId, ownerId);
        boolean directFriend = friends(friendPairs, viewerId, ownerId);
        return new SocialRelationshipContextResponse(
                viewerId,
                ownerId,
                blocked ? "blocked" : directFriend ? "direct_friend" : "public",
                directFriend ? 1 : 0,
                directFriend ? 80.0 : 0.0,
                blocked,
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
                visibility(viewerId, ownerId, blocked, directFriend));
    }

    private SocialAudienceDecisionResponse audienceDecision(SocialContentRecord content, String viewerId) {
        return new SocialAudienceDecisionResponse(
                content.ownerId(),
                viewerId,
                content.scope(),
                content.targetId(),
                true,
                "public",
                "public",
                false,
                false,
                false,
                false,
                visibility(viewerId, content.ownerId(), false, false));
    }

    private VisibilityDecision visibility(String viewerId, String ownerId, boolean blocked, boolean directFriend) {
        return new VisibilityDecision(
                viewerId,
                ownerId,
                blocked ? "blocked" : directFriend ? "direct_friend" : "public",
                !blocked,
                !blocked,
                !blocked,
                !blocked,
                blocked ? "blocked" : "public");
    }

    private SocialUserProfileRecord profile(String userId, String visibility) {
        return new SocialUserProfileRecord(
                userId,
                userId,
                userId + " display",
                userId + " bio",
                userId + " avatar",
                userId + " site",
                userId + " location",
                visibility,
                NOW,
                NOW.plusSeconds(30));
    }

    private SocialContentRecord content(String contentId, String ownerId, String scope) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "post",
                scope,
                "",
                contentId,
                NOW);
    }

    private boolean blocked(Set<String> blockedPairs, String firstUserId, String secondUserId) {
        return blockedPairs.contains(pair(firstUserId, secondUserId))
                || blockedPairs.contains(pair(secondUserId, firstUserId));
    }

    private boolean friends(Set<String> friendPairs, String firstUserId, String secondUserId) {
        return friendPairs.contains(pair(firstUserId, secondUserId))
                || friendPairs.contains(pair(secondUserId, firstUserId));
    }

    private String pair(String firstUserId, String secondUserId) {
        return firstUserId + "|" + secondUserId;
    }
}
