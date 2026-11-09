package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRecommendationPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T04:00:00Z");

    @Test
    void ranksRecommendationsFromMutualFamilyAndSharedCircleSignals() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRecommendationPlanner planner = new SocialRecommendationPlanner(repository);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "rich_candidate", BASE_TIME);
        repository.saveFriendship("user_a", "direct_friend", BASE_TIME);
        repository.saveFriendship("bridge", "direct_friend", BASE_TIME);
        repository.saveFriendship("bridge", "pending_candidate", BASE_TIME);
        repository.saveFriendship("bridge", "blocked_candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_candidate", "sibling", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("rich_candidate", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("shared_group_candidate", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("direct_friend", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("pending_candidate", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("blocked_candidate", "group_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("rich_candidate", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord(
                "shared_community_candidate",
                "community_a",
                "member",
                BASE_TIME));
        repository.saveFriendRequest(new FriendRequestRecord(
                "request_pending",
                "user_a",
                "pending_candidate",
                "",
                "pending",
                BASE_TIME,
                BASE_TIME));
        repository.saveBlock(new BlockRecord("user_a", "blocked_candidate", "", BASE_TIME));

        List<SocialRecommendationPlanner.Candidate> recommendations = planner.recommendations("user_a", 10);

        assertEquals(List.of(
                "rich_candidate",
                "family_candidate",
                "shared_group_candidate",
                "shared_community_candidate"), userIds(recommendations));
        SocialRecommendationPlanner.Candidate richCandidate = recommendations.getFirst();
        assertEquals("mutual_friends", richCandidate.reason());
        assertEquals(17.0, richCandidate.score());
        assertEquals(List.of("bridge"), richCandidate.mutualFriendIds());
        assertEquals(List.of("group_a"), richCandidate.sharedGroupIds());
        assertEquals(List.of("community_a"), richCandidate.sharedCommunityIds());
        assertFalse(userIds(recommendations).contains("direct_friend"));
        assertFalse(userIds(recommendations).contains("pending_candidate"));
        assertFalse(userIds(recommendations).contains("blocked_candidate"));
    }

    @Test
    void keepsFamilyReasonWhenCandidateAlsoHasMutualFriendSignal() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRecommendationPlanner planner = new SocialRecommendationPlanner(repository);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "family_mutual_candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord(
                "user_a",
                "family_mutual_candidate",
                "sibling",
                BASE_TIME));

        SocialRecommendationPlanner.Candidate candidate = planner.recommendations("user_a", 10).getFirst();

        assertEquals("family_mutual_candidate", candidate.userId());
        assertEquals("family", candidate.reason());
        assertTrue(candidate.familyLink());
        assertEquals(22.0, candidate.score());
        assertEquals(List.of("bridge"), candidate.mutualFriendIds());
    }

    @Test
    void recommendsFollowGraphCandidatesWithSocialProof() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRecommendationPlanner planner = new SocialRecommendationPlanner(repository);
        repository.saveFriendship("user_a", "bridge_a", BASE_TIME);
        repository.saveFriendship("user_a", "bridge_b", BASE_TIME);
        repository.saveUserFollow(new SocialUserFollowRecord(
                "bridge_a",
                "followed_by_friend_candidate",
                BASE_TIME.plusSeconds(1)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "bridge_b",
                "followed_by_friend_candidate",
                BASE_TIME.plusSeconds(2)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "follows_viewer_candidate",
                "user_a",
                BASE_TIME.plusSeconds(3)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "user_a",
                "already_followed_candidate",
                BASE_TIME.plusSeconds(4)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "bridge_a",
                "already_followed_candidate",
                BASE_TIME.plusSeconds(5)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "bridge_a",
                "pending_follow_candidate",
                BASE_TIME.plusSeconds(6)));
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "user_a",
                "pending_follow_candidate",
                "pending",
                BASE_TIME.plusSeconds(7),
                BASE_TIME.plusSeconds(7)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "blocked_follower_candidate",
                "user_a",
                BASE_TIME.plusSeconds(8)));
        repository.saveBlock(new BlockRecord("blocked_follower_candidate", "user_a", "", BASE_TIME.plusSeconds(9)));

        List<SocialRecommendationPlanner.Candidate> recommendations = planner.recommendations("user_a", 10);

        assertEquals(List.of("followed_by_friend_candidate", "follows_viewer_candidate"), userIds(recommendations));
        SocialRecommendationPlanner.Candidate followedByFriend = recommendations.getFirst();
        assertEquals("followed_by_friends", followedByFriend.reason());
        assertEquals(2, followedByFriend.followedByFriendCount());
        assertEquals(List.of("bridge_a", "bridge_b"), followedByFriend.followedByFriendIds());
        assertFalse(followedByFriend.followsViewer());

        SocialRecommendationPlanner.Candidate followsViewer = recommendations.get(1);
        assertEquals("follows_you", followsViewer.reason());
        assertTrue(followsViewer.followsViewer());
        assertEquals(5.0, followsViewer.score());

        assertFalse(userIds(recommendations).contains("already_followed_candidate"));
        assertFalse(userIds(recommendations).contains("pending_follow_candidate"));
        assertFalse(userIds(recommendations).contains("blocked_follower_candidate"));
    }

    @Test
    void appliesLimitAfterRankingCandidates() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRecommendationPlanner planner = new SocialRecommendationPlanner(repository);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "mutual_candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_candidate", "sibling", BASE_TIME));

        List<SocialRecommendationPlanner.Candidate> recommendations = planner.recommendations("user_a", 1);

        assertEquals(List.of("family_candidate"), userIds(recommendations));
    }

    private List<String> userIds(List<SocialRecommendationPlanner.Candidate> recommendations) {
        return recommendations.stream().map(SocialRecommendationPlanner.Candidate::userId).toList();
    }
}
