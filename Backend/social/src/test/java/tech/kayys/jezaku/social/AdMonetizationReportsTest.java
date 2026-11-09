package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceRelationMetrics;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyReportResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class AdMonetizationReportsTest {
    @Test
    void buildsCampaignMetricsAndBillingResponses() {
        Instant now = Instant.parse("2026-06-02T11:00:00Z");
        SocialAdCampaignRecord campaign = campaign("campaign_metrics", "USD", 1_000L, now);
        List<SocialAdEventRecord> events = List.of(
                event("event_impression", campaign, "viewer_a", "impression", now.minusSeconds(180)),
                event("event_click", campaign, "viewer_a", "click", now.minusSeconds(120)),
                event("event_conversion", campaign, "viewer_b", "conversion", now.minusSeconds(60)));
        List<SocialAdAudienceRelationMetrics> relationMetrics = List.of(metric("friend", events.size()));

        SocialAdCampaignMetricsResponse metrics = AdMonetizationReports.campaignMetricsResponse(
                campaign,
                events,
                relationMetrics,
                now);
        SocialAdBillingLedgerResponse ledger = AdMonetizationReports.billingLedgerResponse(campaign, events, 2);

        assertEquals(campaign.campaignId(), metrics.campaignId());
        assertEquals(126L, metrics.spentCents());
        assertEquals(874L, metrics.remainingBudgetCents());
        assertFalse(metrics.budgetExhausted());
        assertEquals(1, metrics.impressionCount());
        assertEquals(1, metrics.clickCount());
        assertEquals(1, metrics.conversionCount());
        assertEquals(2, metrics.uniqueViewerCount());
        assertEquals(1.0, metrics.clickThroughRate());
        assertEquals(relationMetrics, metrics.audienceRelationMetrics());
        assertEquals(now.minusSeconds(60), metrics.lastEventAt());
        assertEquals(126L, ledger.spentCents());
        assertEquals(874L, ledger.remainingBudgetCents());
        assertEquals(2, ledger.count());
        assertEquals(2, ledger.entries().size());
        assertEquals(1L, ledger.entries().getFirst().billableCents());
        assertEquals(26L, ledger.entries().get(1).cumulativeSpentCents());
    }

    @Test
    void buildsCampaignAndAdvertiserDailyReports() {
        Instant now = Instant.parse("2026-06-02T11:00:00Z");
        SocialAdCampaignRecord usdCampaign = campaign("campaign_usd", "USD", 1_000L, now);
        SocialAdCampaignRecord idrCampaign = campaign("campaign_idr", "IDR", 100_000L, now);
        SocialAdEventRecord yesterdayEvent = event(
                "event_yesterday",
                usdCampaign,
                "viewer_a",
                "impression",
                now.minusSeconds(86_400));
        SocialAdEventRecord todayEvent = event(
                "event_today",
                idrCampaign,
                "viewer_b",
                "click",
                now.minusSeconds(60));

        SocialAdDailyReportResponse campaignReport = AdMonetizationReports.campaignDailyReportResponse(
                usdCampaign,
                List.of(yesterdayEvent),
                2,
                now);
        SocialAdAdvertiserDailyReportResponse advertiserReport = AdMonetizationReports.advertiserDailyReportResponse(
                "advertiser_a",
                "all",
                10,
                2,
                now,
                List.of(usdCampaign, idrCampaign),
                List.of(yesterdayEvent, todayEvent));

        assertEquals(usdCampaign.campaignId(), campaignReport.campaignId());
        assertEquals(2, campaignReport.buckets().size());
        assertEquals(1, campaignReport.buckets().getFirst().impressionCount());
        assertEquals(0, campaignReport.buckets().get(1).clickCount());
        assertEquals("MIXED", advertiserReport.budgetCurrency());
        assertEquals(2, advertiserReport.campaignCount());
        assertEquals(10, advertiserReport.limit());
        assertEquals(2, advertiserReport.windowDays());
        assertEquals(2, advertiserReport.buckets().size());
        assertEquals(1, advertiserReport.buckets().get(1).clickCount());
    }

    @Test
    void buildsAudienceRelationMetricsFromCampaignAudienceResolver() {
        Instant now = Instant.parse("2026-06-02T11:00:00Z");
        SocialAdCampaignRecord campaign = campaign("campaign_relations", "USD", 1_000L, now);
        List<SocialAdEventRecord> events = List.of(
                event("event_friend", campaign, "viewer_friend", "impression", now.minusSeconds(30)),
                event("event_unmatched", campaign, "viewer_unmatched", "click", now.minusSeconds(10)));

        List<SocialAdAudienceRelationMetrics> metrics = AdMonetizationReports.audienceRelationMetrics(
                campaign,
                events,
                (candidateCampaign, viewerId) -> "viewer_friend".equals(viewerId)
                        ? audienceCandidate("friend", 72.5)
                        : null);

        assertEquals(2, metrics.size());
        assertEquals("friend", metrics.getFirst().relation());
        assertEquals(1, metrics.getFirst().impressionCount());
        assertEquals(72.5, metrics.getFirst().averageRelevanceScore(), 0.0001);
        assertEquals("unmatched", metrics.get(1).relation());
        assertEquals(25L, metrics.get(1).spentCents());
        assertEquals(1, metrics.get(1).clickCount());
        assertEquals(0.0, metrics.get(1).averageRelevanceScore(), 0.0001);
    }

    private SocialAdCampaignRecord campaign(String campaignId, String budgetCurrency, long budgetCents, Instant now) {
        return new SocialAdCampaignRecord(
                campaignId,
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                "scheduled",
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
                Instant.parse("2026-06-02T11:00:00Z"));
    }

    private SocialAdAudienceCandidate audienceCandidate(String relation, double relevanceScore) {
        return new SocialAdAudienceCandidate(
                "viewer_friend",
                "Viewer Friend",
                relation,
                1,
                60.0,
                List.of(relation),
                List.of("citywalk"),
                List.of(),
                List.of(),
                2,
                relevanceScore,
                List.of("relation:" + relation));
    }
}
