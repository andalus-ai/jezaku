package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AdAudienceCandidateResolverTest {
    @Test
    void resolvesAudienceCandidateFromGraphFactsAndTargets() {
        AdAudienceCandidateResolver resolver = resolver(
                context(true, false, 1, 72.0),
                true,
                List.of("group_shared"),
                List.of("community_shared"),
                true,
                Set.of("citywalk", "maker"),
                Set.of("group_target", "group_shared"),
                Set.of("community_target"),
                3);

        SocialAdAudienceCandidate candidate = resolver.candidate(
                "advertiser_a",
                "viewer_a",
                2,
                Set.of("friend", "shared_group"),
                Set.of("citywalk"),
                Set.of("group_target"),
                Set.of("community_target"));

        assertEquals("viewer_a", candidate.userId());
        assertEquals("Viewer A", candidate.displayName());
        assertEquals("friend", candidate.primaryRelation());
        assertEquals(1, candidate.connectionDepth());
        assertEquals(List.of("citywalk"), candidate.matchedTags());
        assertEquals(List.of("group_target"), candidate.matchedGroupIds());
        assertEquals(List.of("community_target"), candidate.matchedCommunityIds());
        assertEquals(3, candidate.visibleContentCount());
        assertTrue(candidate.relations().contains("friend"));
        assertTrue(candidate.relations().contains("friend_of_friend"));
        assertTrue(candidate.relations().contains("shared_group"));
        assertTrue(candidate.relations().contains("shared_community"));
        assertTrue(candidate.relations().contains("follower"));
        assertTrue(candidate.reasons().contains("target_tags"));
        assertTrue(candidate.reasons().contains("target_groups"));
        assertTrue(candidate.reasons().contains("target_communities"));
        assertTrue(candidate.reasons().contains("visible_creator_activity"));
    }

    @Test
    void rejectsCandidatesOutsideDepthRelationOrTargetFilters() {
        AdAudienceCandidateResolver resolver = resolver(
                context(false, false, 3, 12.0),
                false,
                List.of(),
                List.of(),
                false,
                Set.of("citywalk"),
                Set.of("group_a"),
                Set.of("community_a"),
                0);

        assertNull(resolver.candidate(
                "advertiser_a",
                "viewer_a",
                2,
                Set.of(),
                Set.of(),
                Set.of(),
                Set.of()));
        assertNull(resolver.candidate(
                "advertiser_a",
                "viewer_a",
                3,
                Set.of("friend"),
                Set.of(),
                Set.of(),
                Set.of()));
        assertNull(resolver.candidate(
                "advertiser_a",
                "viewer_a",
                3,
                Set.of(),
                Set.of("missing_tag"),
                Set.of(),
                Set.of()));
    }

    @Test
    void resolvesCampaignCandidateFromCampaignTargetSnapshot() {
        AdAudienceCandidateResolver resolver = resolver(
                context(false, true, 2, 48.0),
                false,
                List.of("group_shared"),
                List.of(),
                false,
                Set.of("camera"),
                Set.of("group_shared"),
                Set.of(),
                1);

        SocialAdAudienceCandidate candidate = resolver.campaignCandidate(campaign(), "viewer_a");

        assertEquals("family", candidate.primaryRelation());
        assertEquals(List.of("group_shared"), candidate.matchedGroupIds());
        assertEquals(List.of("camera"), candidate.matchedTags());
    }

    private AdAudienceCandidateResolver resolver(
            SocialRelationshipContextResponse context,
            boolean friendOfFriend,
            List<String> sharedGroups,
            List<String> sharedCommunities,
            boolean followsAdvertiser,
            Set<String> tags,
            Set<String> groups,
            Set<String> communities,
            int visibleContentCount) {
        return new AdAudienceCandidateResolver(
                new TestGraphSignals(
                        context,
                        friendOfFriend,
                        sharedGroups,
                        sharedCommunities,
                        followsAdvertiser,
                        tags,
                        groups,
                        communities,
                        visibleContentCount));
    }

    private record TestGraphSignals(
            SocialRelationshipContextResponse context,
            boolean friendOfFriend,
            List<String> sharedGroups,
            List<String> sharedCommunities,
            boolean followsAdvertiser,
            Set<String> tags,
            Set<String> groups,
            Set<String> communities,
            int visibleContentCount) implements AdAudienceGraphSignals {
        @Override
        public SocialRelationshipContextResponse relationshipContext(String advertiserId, String candidateUserId) {
            return context;
        }

        @Override
        public boolean friendOfFriend(String advertiserId, String candidateUserId) {
            return friendOfFriend;
        }

        @Override
        public List<String> sharedGroupIds(String advertiserId, String candidateUserId) {
            return sharedGroups;
        }

        @Override
        public List<String> sharedCommunityIds(String advertiserId, String candidateUserId) {
            return sharedCommunities;
        }

        @Override
        public boolean candidateFollowsAdvertiser(String advertiserId, String candidateUserId) {
            return followsAdvertiser;
        }

        @Override
        public Set<String> userInterestTags(String userId) {
            return tags;
        }

        @Override
        public Set<String> userGroupIds(String userId) {
            return groups;
        }

        @Override
        public Set<String> userCommunityIds(String userId) {
            return communities;
        }

        @Override
        public int visibleContentCount(String advertiserId, String candidateUserId) {
            return visibleContentCount;
        }

        @Override
        public String userLabel(String userId) {
            return Map.of("viewer_a", "Viewer A").getOrDefault(userId, userId);
        }
    }

    private SocialRelationshipContextResponse context(
            boolean directFriend,
            boolean family,
            int depth,
            double affinityScore) {
        return new SocialRelationshipContextResponse(
                "advertiser_a",
                "viewer_a",
                directFriend ? "friend" : family ? "family" : "public",
                depth,
                affinityScore,
                false,
                directFriend,
                false,
                false,
                family,
                family ? "sibling" : "",
                "",
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                null);
    }

    private SocialAdCampaignRecord campaign() {
        Instant now = Instant.parse("2026-06-02T15:00:00Z");
        return new SocialAdCampaignRecord(
                "campaign_a",
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                "scheduled",
                "",
                "approved",
                "",
                now.minusSeconds(600),
                "USD",
                10_000L,
                now.minusSeconds(3_600),
                now.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("family", "shared_group"),
                List.of("camera"),
                List.of("group_shared"),
                List.of(),
                now.minusSeconds(7_200),
                now.minusSeconds(1_800));
    }
}
