package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Set;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AdAudiencePlannerTest {
    @Test
    void ranksCandidatesAndReportsBlockedExclusionsAndSegments() {
        Map<String, SocialAdAudienceCandidate> candidates = Map.of(
                "user_low", candidate("user_low", "public", 1, 28.0, 25.0),
                "user_high", candidate("user_high", "friend", 1, 82.0, 73.0),
                "user_group", candidate("user_group", "shared_group", 2, 60.0, 60.0));

        SocialAdAudiencePreviewResponse preview = AdAudiencePlanner.preview(
                "advertiser_a",
                "engagement",
                2,
                2,
                Set.of("citywalk"),
                Set.of("group_a"),
                Set.of(),
                List.of("advertiser_a", "user_blocked", "user_low", "user_high", "user_group"),
                (advertiserId, candidateUserId) -> "user_blocked".equals(candidateUserId),
                candidates::get);

        assertEquals(3, preview.estimatedReach());
        assertEquals(2, preview.returnedCount());
        assertEquals(1, preview.blockedExcludedCount());
        assertEquals("user_high", preview.candidates().getFirst().userId());
        assertEquals("user_group", preview.candidates().get(1).userId());
        assertEquals("friend", preview.segments().getFirst().segment());
        assertEquals(List.of("user_high"), preview.segments().getFirst().userIds());
        assertTrue(preview.segments().stream()
                .anyMatch(segment -> segment.segment().equals("shared_group")
                        && segment.userIds().equals(List.of("user_group"))));
    }

    @Test
    void computesRelationDepthOrderingScoreAndReasons() {
        List<String> relations = AdAudiencePlanner.sortedRelations(Set.of("public", "follower", "friend"));
        double score = AdAudiencePlanner.relevanceScore(
                80.0,
                relations.getFirst(),
                relations,
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                4);
        List<String> reasons = AdAudiencePlanner.reasons(
                relations.getFirst(),
                relations,
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                4);

        assertEquals(List.of("friend", "follower", "public"), relations);
        assertEquals(1, AdAudiencePlanner.audienceDepth(3, Set.of("friend")));
        assertEquals(2, AdAudiencePlanner.audienceDepth(-1, Set.of("friend_of_friend")));
        assertEquals(100.0, score);
        assertTrue(reasons.contains("relation:friend"));
        assertTrue(reasons.contains("follows_advertiser"));
        assertTrue(reasons.contains("target_tags"));
        assertTrue(reasons.contains("target_groups"));
        assertTrue(reasons.contains("target_communities"));
        assertTrue(reasons.contains("visible_creator_activity"));
    }

    private SocialAdAudienceCandidate candidate(
            String userId,
            String primaryRelation,
            int depth,
            double relevanceScore,
            double affinityScore) {
        return new SocialAdAudienceCandidate(
                userId,
                userId,
                primaryRelation,
                depth,
                affinityScore,
                List.of(primaryRelation),
                List.of(),
                List.of(),
                List.of(),
                0,
                relevanceScore,
                List.of("relation:" + primaryRelation));
    }
}
