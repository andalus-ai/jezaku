package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceRelationMetrics;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AdAdvertiserDashboardTest {
    @Test
    void aggregatesAdvertiserPortfolioDashboard() {
        Instant now = Instant.parse("2026-06-02T10:00:00Z");
        SocialAdCampaignRecord active = campaign("campaign_active", "scheduled", 1_000L, now);
        SocialAdCampaignRecord exhausted = campaign("campaign_exhausted", "paused", 100L, now);
        Map<String, List<SocialAdEventRecord>> eventsByCampaign = Map.of(
                active.campaignId(), List.of(
                        event("event_impression", active, "viewer_a", "impression", now.minusSeconds(180)),
                        event("event_click", active, "viewer_a", "click", now.minusSeconds(120)),
                        event("event_conversion", active, "viewer_b", "conversion", now.minusSeconds(60))),
                exhausted.campaignId(), List.of(
                        event("event_exhausted", exhausted, "viewer_c", "conversion", now.minusSeconds(30))));

        SocialAdAdvertiserDashboardResponse response = AdAdvertiserDashboard.response(
                "advertiser_a",
                "all",
                10,
                List.of(active, exhausted),
                campaign -> eventsByCampaign.getOrDefault(campaign.campaignId(), List.of()),
                (campaign, events) -> List.of(metric("campaign_" + campaign.campaignId(), events.size())),
                (events, campaignsById) -> List.of(metric("portfolio_" + campaignsById.size(), events.size())),
                now);

        assertEquals("advertiser_a", response.advertiserId());
        assertEquals("all", response.status());
        assertEquals("USD", response.budgetCurrency());
        assertEquals(2, response.count());
        assertEquals(10, response.limit());
        assertEquals(1_100L, response.totalBudgetCents());
        assertEquals(226L, response.totalSpentCents());
        assertEquals(874L, response.totalRemainingBudgetCents());
        assertEquals(1, response.activeCampaignCount());
        assertEquals(1, response.exhaustedCampaignCount());
        assertEquals(1, response.totalImpressionCount());
        assertEquals(1, response.totalClickCount());
        assertEquals(2, response.totalConversionCount());
        assertEquals(3, response.uniqueViewerCount());
        assertEquals(1.0, response.clickThroughRate());
        assertEquals("portfolio_2", response.audienceRelationMetrics().getFirst().relation());
        assertEquals(4, response.audienceRelationMetrics().getFirst().impressionCount());
        assertEquals(2, response.campaigns().size());
        assertEquals("campaign_active", response.campaigns().getFirst().campaignId());
        assertEquals(126L, response.campaigns().getFirst().spentCents());
        assertEquals(874L, response.campaigns().getFirst().remainingBudgetCents());
        assertEquals("campaign_campaign_active", response.campaigns().getFirst().audienceRelationMetrics()
                .getFirst()
                .relation());
        assertEquals("campaign_exhausted", response.campaigns().get(1).campaignId());
        assertEquals(100L, response.campaigns().get(1).spentCents());
        assertEquals(0L, response.campaigns().get(1).remainingBudgetCents());
        assertEquals(true, response.campaigns().get(1).budgetExhausted());
    }

    private SocialAdCampaignRecord campaign(String campaignId, String status, long budgetCents, Instant now) {
        return new SocialAdCampaignRecord(
                campaignId,
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                status,
                "creative_a",
                "approved",
                "",
                now.minusSeconds(600),
                "USD",
                budgetCents,
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

    private SocialAdEventRecord event(
            String eventId,
            SocialAdCampaignRecord campaign,
            String viewerId,
            String eventType,
            Instant occurredAt) {
        return new SocialAdEventRecord(
                eventId,
                campaign.campaignId(),
                campaign.advertiserId(),
                viewerId,
                eventType,
                "feed",
                campaign.creativeContentId(),
                occurredAt,
                occurredAt.plusSeconds(1));
    }

    private SocialAdAudienceRelationMetrics metric(String relation, int eventCount) {
        return new SocialAdAudienceRelationMetrics(
                relation,
                eventCount,
                eventCount,
                0,
                0,
                eventCount,
                0.0,
                1.0,
                Instant.parse("2026-06-02T10:00:00Z"));
    }
}
