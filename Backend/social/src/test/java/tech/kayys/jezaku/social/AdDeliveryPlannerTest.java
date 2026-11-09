package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AdDeliveryPlannerTest {
    @Test
    void buildsDeliveryCandidateWithScoreAndReasons() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");
        SocialAdAudienceCandidate audience = audienceCandidate();

        SocialAdDeliveryCandidate candidate = AdDeliveryPlanner.candidate(
                campaign("approved", now),
                "viewer_a",
                "camera",
                now,
                3,
                campaign -> 5_000L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> audience,
                (campaignId, viewerId, generatedAt) -> 1);

        assertNotNull(candidate);
        assertTrue(candidate.deliveryScore() > audience.relevanceScore());
        assertTrue(candidate.deliveryScore() <= 100.0);
        assertTrue(candidate.reasons().contains("relation:friend"));
        assertTrue(candidate.reasons().contains("placement:camera"));
        assertTrue(candidate.reasons().contains("objective:engagement"));
        assertTrue(candidate.reasons().contains("creative_review:approved"));
        assertTrue(candidate.reasons().contains("creative_visible"));
    }

    @Test
    void rejectsUnapprovedCreativeAndFrequencyCappedViewer() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");
        SocialAdAudienceCandidate audience = audienceCandidate();

        assertNull(AdDeliveryPlanner.candidate(
                campaign("pending_review", now),
                "viewer_a",
                "feed",
                now,
                3,
                campaign -> 5_000L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> audience,
                (campaignId, viewerId, generatedAt) -> 0));

        assertNull(AdDeliveryPlanner.candidate(
                campaign("approved", now),
                "viewer_a",
                "feed",
                now,
                3,
                campaign -> 5_000L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> audience,
                (campaignId, viewerId, generatedAt) -> 3));
    }

    @Test
    void buildsDeliveryResponseSortedByScoreAndLimited() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");
        SocialAdCampaignRecord lowerScore = campaign("campaign_low", "awareness", "approved", now);
        SocialAdCampaignRecord higherScore = campaign("campaign_high", "engagement", "approved", now);

        SocialAdDeliveryResponse response = AdDeliveryPlanner.response(
                "viewer_a",
                "story",
                1,
                now,
                List.of(lowerScore, higherScore),
                3,
                campaign -> 5_000L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> "campaign_high".equals(campaign.campaignId())
                        ? audienceCandidate(90.0)
                        : audienceCandidate(70.0),
                (campaignId, viewerId, generatedAt) -> 0);

        assertEquals("viewer_a", response.viewerId());
        assertEquals("story", response.placement());
        assertEquals(1, response.limit());
        assertEquals(1, response.count());
        assertEquals(now, response.generatedAt());
        assertEquals("campaign_high", response.candidates().getFirst().campaignId());
    }

    private SocialAdCampaignRecord campaign(String creativeReviewStatus, Instant now) {
        return campaign("campaign_a", "engagement", creativeReviewStatus, now);
    }

    private SocialAdCampaignRecord campaign(
            String campaignId,
            String objective,
            String creativeReviewStatus,
            Instant now) {
        return new SocialAdCampaignRecord(
                campaignId,
                "advertiser_a",
                "Neighborhood launch",
                objective,
                "scheduled",
                "creative_a",
                creativeReviewStatus,
                "",
                "approved".equals(creativeReviewStatus) ? now.minusSeconds(600) : null,
                "USD",
                10_000L,
                now.minusSeconds(3_600),
                now.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                now.minusSeconds(7_200),
                now.minusSeconds(1_800));
    }

    private SocialAdAudienceCandidate audienceCandidate() {
        return audienceCandidate(82.0);
    }

    private SocialAdAudienceCandidate audienceCandidate(double relevanceScore) {
        return new SocialAdAudienceCandidate(
                "viewer_a",
                "Viewer A",
                "friend",
                1,
                73.5,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                4,
                relevanceScore,
                List.of("relation:friend"));
    }
}
