package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialContentRankingPolicyTest {
    private static final Instant NOW = Instant.parse("2026-06-04T00:00:00Z");
    private static final Instant ONE_DAY_OLD = NOW.minusSeconds(86_400);

    private final SocialContentRankingPolicy policy =
            new SocialContentRankingPolicy(Clock.fixed(NOW, ZoneOffset.UTC));

    @Test
    void scoresContentSurfacesFromSharedWeightsAndRecency() {
        SocialContentRecord content = new SocialContentRecord(
                "content_a",
                "owner_a",
                "photo",
                "group",
                "group_a",
                "hello",
                ONE_DAY_OLD);
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                new SocialEngagementSummaryResolver.ContentEngagementSummary(2, 3, 5, 7, true, true);
        SocialRelationshipContextResponse context = relationshipContext(12.5);

        assertEquals(57.5, policy.feedScore(content, context, engagement), 0.0001);
        assertEquals(94.0, policy.contentSearchScore(70.0, content, engagement), 0.0001);
        assertEquals(40.0, policy.trendingContribution(content, engagement), 0.0001);
        assertEquals(59.0, policy.topicFeedScore(content, 2, engagement), 0.0001);
    }

    @Test
    void capsSearchEngagementAndFloorsOldRecency() {
        SocialContentRecord oldContent = new SocialContentRecord(
                "content_old",
                "owner_a",
                "post",
                "public",
                "",
                "old",
                NOW.minusSeconds(10 * 86_400));
        SocialEngagementSummaryResolver.ContentEngagementSummary heavyEngagement =
                new SocialEngagementSummaryResolver.ContentEngagementSummary(100, 100, 100, 100, false, false);

        assertEquals(35.0, policy.contentSearchScore(15.0, oldContent, heavyEngagement), 0.0001);
    }

    private SocialRelationshipContextResponse relationshipContext(double affinityScore) {
        return new SocialRelationshipContextResponse(
                "viewer_a",
                "owner_a",
                "friend",
                1,
                affinityScore,
                false,
                true,
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
                new VisibilityDecision(
                        "viewer_a",
                        "owner_a",
                        "friend",
                        true,
                        true,
                        true,
                        true,
                        "friend"));
    }
}
