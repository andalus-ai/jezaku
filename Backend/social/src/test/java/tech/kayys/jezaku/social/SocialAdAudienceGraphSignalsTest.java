package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialAdAudienceGraphSignalsTest {
    @Test
    void delegatesAudienceSignalsThroughSocialIndexes() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Instant now = Instant.parse("2026-06-02T20:00:00Z");
        SocialRelationshipContextResponse context = context();

        repository.saveFriendship("advertiser_a", "bridge_a", now);
        repository.saveFriendship("bridge_a", "candidate_a", now);
        repository.saveUserFollow(new SocialUserFollowRecord("candidate_a", "advertiser_a", now));
        repository.saveGroupMembership(new MembershipRecord("advertiser_a", "group_shared", "owner", now));
        repository.saveGroupMembership(new MembershipRecord("candidate_a", "group_shared", "member", now));
        repository.saveGroupMembership(new MembershipRecord("candidate_a", "group_target", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("advertiser_a", "community_shared", "owner", now));
        repository.saveCommunityMembership(new MembershipRecord("candidate_a", "community_shared", "member", now));
        repository.saveCommunityMembership(new MembershipRecord("candidate_a", "community_target", "member", now));
        repository.saveTagFollow(new SocialTagFollowRecord("candidate_a", "citywalk", now));

        AdAudienceGraphSignals signals = new SocialAdAudienceGraphSignals(
                (advertiserId, candidateUserId) -> context,
                new SocialConnectionIndex(repository),
                new SocialCircleMembershipIndex(repository),
                new SocialUserInterestIndex(repository),
                (advertiserId, candidateUserId) -> 4,
                userId -> "Candidate A");

        assertSame(context, signals.relationshipContext("advertiser_a", "candidate_a"));
        assertTrue(signals.friendOfFriend("advertiser_a", "candidate_a"));
        assertTrue(signals.candidateFollowsAdvertiser("advertiser_a", "candidate_a"));
        assertEquals(List.of("group_shared"), signals.sharedGroupIds("advertiser_a", "candidate_a"));
        assertEquals(List.of("community_shared"), signals.sharedCommunityIds("advertiser_a", "candidate_a"));
        assertEquals(Set.of("citywalk"), signals.userInterestTags("candidate_a"));
        assertEquals(Set.of("group_shared", "group_target"), signals.userGroupIds("candidate_a"));
        assertEquals(Set.of("community_shared", "community_target"), signals.userCommunityIds("candidate_a"));
        assertEquals(4, signals.visibleContentCount("advertiser_a", "candidate_a"));
        assertEquals("Candidate A", signals.userLabel("candidate_a"));
    }

    private SocialRelationshipContextResponse context() {
        return new SocialRelationshipContextResponse(
                "advertiser_a",
                "candidate_a",
                "friend_of_friend",
                2,
                32.0,
                false,
                false,
                false,
                false,
                false,
                "",
                "",
                0,
                1,
                1,
                List.of(),
                List.of("group_shared"),
                List.of("community_shared"),
                null);
    }
}
