package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdCampaignReportingReadModelTest {
    private static final Instant NOW = Instant.parse("2026-06-04T08:00:00Z");

    @Test
    void buildsCampaignMetricsAndBillingLedgerForAdvertiserCampaign() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialAdCampaignRecord campaign = campaign(
                "campaign_scheduled",
                "advertiser_a",
                "scheduled",
                1_000L,
                "USD",
                NOW.minusSeconds(2_000));
        repository.saveAdCampaign(campaign);
        repository.saveAdEvent(event("event_click", campaign, "viewer_a", "click", NOW.minusSeconds(30)));
        repository.saveAdEvent(event("event_impression", campaign, "viewer_a", "impression", NOW.minusSeconds(60)));
        AdCampaignReportingReadModel model = model(repository);

        SocialAdCampaignMetricsResponse metrics = model.campaignMetrics(campaign.campaignId(), "advertiser_a");
        SocialAdBillingLedgerResponse ledger = model.campaignBillingLedger(campaign.campaignId(), "advertiser_a", 1);

        assertEquals(campaign.campaignId(), metrics.campaignId());
        assertEquals(26L, metrics.spentCents());
        assertEquals(974L, metrics.remainingBudgetCents());
        assertEquals(1, metrics.impressionCount());
        assertEquals(1, metrics.clickCount());
        assertEquals(1.0, metrics.clickThroughRate());
        assertEquals("feed", metrics.placementMetrics().getFirst().placement());
        assertEquals("friend", metrics.audienceRelationMetrics().getFirst().relation());
        assertEquals(1, metrics.audienceRelationMetrics().getFirst().uniqueViewerCount());
        assertEquals(26L, ledger.spentCents());
        assertEquals(1, ledger.count());
        assertEquals(1, ledger.entries().size());
        assertEquals("event_impression", ledger.entries().getFirst().eventId());
        assertEquals(1L, ledger.entries().getFirst().billableCents());
    }

    @Test
    void advertiserReportsAggregateOnlySelectedCampaignSlice() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialAdCampaignRecord scheduled = campaign(
                "campaign_scheduled",
                "advertiser_a",
                "scheduled",
                1_000L,
                "USD",
                NOW.minusSeconds(2_000));
        SocialAdCampaignRecord paused = campaign(
                "campaign_paused",
                "advertiser_a",
                "paused",
                500L,
                "USD",
                NOW.minusSeconds(1_000));
        SocialAdCampaignRecord otherAdvertiser = campaign(
                "campaign_other",
                "advertiser_b",
                "scheduled",
                700L,
                "USD",
                NOW.minusSeconds(500));
        repository.saveAdCampaign(scheduled);
        repository.saveAdCampaign(paused);
        repository.saveAdCampaign(otherAdvertiser);
        repository.saveAdEvent(event(
                "event_scheduled_impression",
                scheduled,
                "viewer_a",
                "impression",
                NOW.minusSeconds(60)));
        repository.saveAdEvent(event(
                "event_scheduled_click",
                scheduled,
                "viewer_a",
                "click",
                NOW.minusSeconds(30)));
        repository.saveAdEvent(event(
                "event_paused_conversion",
                paused,
                "viewer_b",
                "conversion",
                NOW.minusSeconds(20)));
        repository.saveAdEvent(event(
                "event_other",
                otherAdvertiser,
                "viewer_c",
                "impression",
                NOW.minusSeconds(10)));
        AdCampaignReportingReadModel model = model(repository);

        SocialAdAdvertiserDashboardResponse dashboard = model.advertiserDashboard("advertiser_a", "all", 10);
        SocialAdAdvertiserDailyReportResponse dailyReport = model.advertiserDailyReport(
                "advertiser_a",
                "scheduled",
                1,
                10);

        assertEquals("advertiser_a", dashboard.advertiserId());
        assertEquals("all", dashboard.status());
        assertEquals(2, dashboard.count());
        assertEquals(1_500L, dashboard.totalBudgetCents());
        assertEquals(126L, dashboard.totalSpentCents());
        assertEquals(1, dashboard.activeCampaignCount());
        assertEquals(1, dashboard.totalImpressionCount());
        assertEquals(1, dashboard.totalClickCount());
        assertEquals(1, dashboard.totalConversionCount());
        assertEquals(2, dashboard.uniqueViewerCount());
        assertEquals(2, dashboard.campaigns().size());
        assertEquals("scheduled", dailyReport.status());
        assertEquals(1, dailyReport.campaignCount());
        assertEquals(1, dailyReport.windowDays());
        assertEquals(NOW, dailyReport.generatedAt());
        assertEquals(1, dailyReport.buckets().getFirst().impressionCount());
        assertEquals(1, dailyReport.buckets().getFirst().clickCount());
        assertEquals(0, dailyReport.buckets().getFirst().conversionCount());
    }

    @Test
    void validatesAdvertiserAccessAndReportBounds() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialAdCampaignRecord campaign = campaign(
                "campaign_scheduled",
                "advertiser_a",
                "scheduled",
                1_000L,
                "USD",
                NOW.minusSeconds(2_000));
        repository.saveAdCampaign(campaign);
        AdCampaignReportingReadModel model = model(repository);

        assertThrows(ForbiddenException.class, () -> model.campaignMetrics(campaign.campaignId(), "advertiser_b"));
        assertThrows(BadRequestException.class, () -> model.advertiserDashboard("", "all", 10));
        assertThrows(BadRequestException.class, () -> model.advertiserDailyReport("advertiser_a", "all", 91, 10));
        assertThrows(BadRequestException.class, () -> model.campaignBillingLedger(
                campaign.campaignId(),
                "advertiser_a",
                201));
    }

    private AdCampaignReportingReadModel model(InMemorySocialGraphRepository repository) {
        AdMonetizationStore store = new SocialGraphAdMonetizationStore(repository);
        return new AdCampaignReportingReadModel(
                new AdMonetizationReadModel(store, 86_400L),
                new AdAudienceCandidateResolver(new TestGraphSignals()),
                100,
                200,
                90,
                () -> NOW);
    }

    private SocialAdCampaignRecord campaign(
            String campaignId,
            String advertiserId,
            String status,
            long budgetCents,
            String budgetCurrency,
            Instant createdAt) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
                "Neighborhood launch",
                "engagement",
                status,
                "creative_a",
                "approved",
                "",
                NOW.minusSeconds(600),
                budgetCurrency,
                budgetCents,
                NOW.minusSeconds(3_600),
                NOW.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of(),
                List.of(),
                createdAt,
                createdAt);
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

    private record TestGraphSignals() implements AdAudienceGraphSignals {
        @Override
        public SocialRelationshipContextResponse relationshipContext(String advertiserId, String candidateUserId) {
            return new SocialRelationshipContextResponse(
                    advertiserId,
                    candidateUserId,
                    "friend",
                    1,
                    75.0,
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
                    null);
        }

        @Override
        public boolean friendOfFriend(String advertiserId, String candidateUserId) {
            return false;
        }

        @Override
        public List<String> sharedGroupIds(String advertiserId, String candidateUserId) {
            return List.of();
        }

        @Override
        public List<String> sharedCommunityIds(String advertiserId, String candidateUserId) {
            return List.of();
        }

        @Override
        public boolean candidateFollowsAdvertiser(String advertiserId, String candidateUserId) {
            return false;
        }

        @Override
        public Set<String> userInterestTags(String userId) {
            return Set.of("citywalk");
        }

        @Override
        public Set<String> userGroupIds(String userId) {
            return Set.of();
        }

        @Override
        public Set<String> userCommunityIds(String userId) {
            return Set.of();
        }

        @Override
        public int visibleContentCount(String advertiserId, String candidateUserId) {
            return 2;
        }

        @Override
        public String userLabel(String userId) {
            return userId;
        }
    }
}
