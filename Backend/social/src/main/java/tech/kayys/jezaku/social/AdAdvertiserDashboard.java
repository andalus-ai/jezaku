package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceRelationMetrics;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignDashboardSummary;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.BiFunction;
import java.util.function.Function;

final class AdAdvertiserDashboard {
    private AdAdvertiserDashboard() {
    }

    static SocialAdAdvertiserDashboardResponse response(
            String advertiserId,
            String status,
            int limit,
            List<SocialAdCampaignRecord> campaigns,
            Function<SocialAdCampaignRecord, List<SocialAdEventRecord>> eventsForCampaign,
            BiFunction<SocialAdCampaignRecord, List<SocialAdEventRecord>, List<SocialAdAudienceRelationMetrics>>
                    campaignRelationMetrics,
            BiFunction<List<SocialAdEventRecord>, Map<String, SocialAdCampaignRecord>,
                    List<SocialAdAudienceRelationMetrics>> portfolioRelationMetrics,
            Instant now) {
        List<SocialAdCampaignDashboardSummary> summaries = new ArrayList<>();
        Set<String> uniqueViewers = new HashSet<>();
        long totalBudgetCents = 0L;
        long totalSpentCents = 0L;
        long totalRemainingBudgetCents = 0L;
        int activeCampaignCount = 0;
        int exhaustedCampaignCount = 0;
        int totalImpressionCount = 0;
        int totalClickCount = 0;
        int totalConversionCount = 0;
        List<SocialAdEventRecord> dashboardEvents = new ArrayList<>();
        Map<String, SocialAdCampaignRecord> campaignsById = new HashMap<>();

        for (SocialAdCampaignRecord campaign : campaigns) {
            campaignsById.put(campaign.campaignId(), campaign);
            List<SocialAdEventRecord> events = eventsForCampaign.apply(campaign);
            AdCampaignPerformance.Snapshot performance = AdCampaignPerformance.snapshot(campaign, events, now);
            if (performance.active()) {
                activeCampaignCount++;
            }
            if (performance.budgetExhausted()) {
                exhaustedCampaignCount++;
            }
            totalBudgetCents += campaign.budgetCents();
            totalSpentCents += performance.spentCents();
            totalRemainingBudgetCents += performance.remainingBudgetCents();
            totalImpressionCount += performance.impressionCount();
            totalClickCount += performance.clickCount();
            totalConversionCount += performance.conversionCount();
            events.stream()
                    .map(SocialAdEventRecord::viewerId)
                    .forEach(uniqueViewers::add);
            dashboardEvents.addAll(events);
            summaries.add(summary(campaign, events, performance, campaignRelationMetrics.apply(campaign, events)));
        }

        double clickThroughRate = AdMonetizationReports.clickThroughRate(totalImpressionCount, totalClickCount);
        return new SocialAdAdvertiserDashboardResponse(
                advertiserId,
                status,
                AdCampaignPerformance.portfolioBudgetCurrency(campaigns),
                summaries.size(),
                limit,
                totalBudgetCents,
                totalSpentCents,
                totalRemainingBudgetCents,
                activeCampaignCount,
                exhaustedCampaignCount,
                totalImpressionCount,
                totalClickCount,
                totalConversionCount,
                uniqueViewers.size(),
                clickThroughRate,
                AdMonetizationReports.placementMetrics(dashboardEvents),
                portfolioRelationMetrics.apply(dashboardEvents, campaignsById),
                summaries);
    }

    private static SocialAdCampaignDashboardSummary summary(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> events,
            AdCampaignPerformance.Snapshot performance,
            List<SocialAdAudienceRelationMetrics> audienceRelationMetrics) {
        return new SocialAdCampaignDashboardSummary(
                campaign.campaignId(),
                campaign.name(),
                campaign.objective(),
                campaign.status(),
                campaign.creativeReviewStatus(),
                campaign.budgetCurrency(),
                campaign.budgetCents(),
                performance.spentCents(),
                performance.remainingBudgetCents(),
                performance.budgetExhausted(),
                performance.impressionCount(),
                performance.clickCount(),
                performance.conversionCount(),
                performance.uniqueViewerCount(),
                performance.clickThroughRate(),
                AdMonetizationReports.placementMetrics(events),
                audienceRelationMetrics,
                performance.budgetPacing(),
                campaign.startsAt(),
                campaign.endsAt());
    }
}
