package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AdCampaignPerformanceTest {
    @Test
    void buildsCampaignPerformanceSnapshot() {
        Instant now = Instant.parse("2026-06-02T09:00:00Z");
        SocialAdCampaignRecord campaign = campaign("scheduled", "USD", 1_000L, now);
        List<SocialAdEventRecord> events = List.of(
                event("event_impression", campaign, "viewer_a", "impression", now.minusSeconds(120)),
                event("event_click", campaign, "viewer_a", "click", now.minusSeconds(60)),
                event("event_conversion", campaign, "viewer_b", "conversion", now.minusSeconds(30)));

        AdCampaignPerformance.Snapshot snapshot = AdCampaignPerformance.snapshot(campaign, events, now);

        assertEquals(1, snapshot.impressionCount());
        assertEquals(1, snapshot.clickCount());
        assertEquals(1, snapshot.conversionCount());
        assertEquals(2, snapshot.uniqueViewerCount());
        assertEquals(1.0, snapshot.clickThroughRate());
        assertEquals(126L, snapshot.spentCents());
        assertEquals(874L, snapshot.remainingBudgetCents());
        assertFalse(snapshot.budgetExhausted());
        assertTrue(snapshot.active());
        assertNotNull(snapshot.budgetPacing());
        assertEquals(now.minusSeconds(30), snapshot.lastEventAt());
    }

    @Test
    void reportsBudgetCurrencyAndCampaignActivity() {
        Instant now = Instant.parse("2026-06-02T09:00:00Z");
        SocialAdCampaignRecord usdCampaign = campaign("scheduled", "USD", 100L, now);
        SocialAdCampaignRecord idrCampaign = campaign("scheduled", "IDR", 100L, now);
        SocialAdCampaignRecord pausedCampaign = campaign("paused", "USD", 100L, now);
        SocialAdCampaignRecord endedCampaign = campaign("scheduled", "USD", 100L, now)
                .withStatus("scheduled", now);

        assertEquals("USD", AdCampaignPerformance.portfolioBudgetCurrency(List.of()));
        assertEquals("USD", AdCampaignPerformance.portfolioBudgetCurrency(List.of(usdCampaign, pausedCampaign)));
        assertEquals("MIXED", AdCampaignPerformance.portfolioBudgetCurrency(List.of(usdCampaign, idrCampaign)));
        assertTrue(AdCampaignPerformance.active(usdCampaign, now));
        assertFalse(AdCampaignPerformance.active(pausedCampaign, now));
        assertFalse(AdCampaignPerformance.active(endedCampaign, now.plusSeconds(7_200)));
        assertEquals(0L, AdCampaignPerformance.remainingBudgetCents(
                usdCampaign,
                AdCampaignPerformance.spentCents(List.of(
                        event("event_conversion", usdCampaign, "viewer_a", "conversion", now)))));
    }

    private SocialAdCampaignRecord campaign(String status, String budgetCurrency, long budgetCents, Instant now) {
        return new SocialAdCampaignRecord(
                "campaign_" + status + "_" + budgetCurrency,
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                status,
                "creative_a",
                "approved",
                "",
                now.minusSeconds(600),
                budgetCurrency,
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
}
