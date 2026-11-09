package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdBudgetPacing;

import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;

final class AdCampaignPerformance {
    record Snapshot(
            int impressionCount,
            int clickCount,
            int conversionCount,
            int uniqueViewerCount,
            double clickThroughRate,
            long spentCents,
            long remainingBudgetCents,
            boolean budgetExhausted,
            boolean active,
            SocialAdBudgetPacing budgetPacing,
            Instant lastEventAt) {
    }

    private AdCampaignPerformance() {
    }

    static Snapshot snapshot(SocialAdCampaignRecord campaign, List<SocialAdEventRecord> events, Instant now) {
        int impressionCount = AdMonetizationReports.eventCount(events, "impression");
        int clickCount = AdMonetizationReports.eventCount(events, "click");
        int conversionCount = AdMonetizationReports.eventCount(events, "conversion");
        long spentCents = spentCents(events);
        long remainingBudgetCents = remainingBudgetCents(campaign, spentCents);
        return new Snapshot(
                impressionCount,
                clickCount,
                conversionCount,
                AdMonetizationReports.uniqueViewerCount(events),
                AdMonetizationReports.clickThroughRate(impressionCount, clickCount),
                spentCents,
                remainingBudgetCents,
                remainingBudgetCents == 0,
                active(campaign, now),
                AdMonetizationPolicy.budgetPacing(campaign, spentCents, remainingBudgetCents, now),
                AdMonetizationReports.lastEventAt(events));
    }

    static long spentCents(List<SocialAdEventRecord> events) {
        return AdMonetizationPolicy.campaignSpentCents(events);
    }

    static long remainingBudgetCents(SocialAdCampaignRecord campaign, long spentCents) {
        return AdMonetizationPolicy.campaignRemainingBudgetCents(campaign, spentCents);
    }

    static boolean active(SocialAdCampaignRecord campaign, Instant now) {
        return "scheduled".equals(campaign.status())
                && !campaign.startsAt().isAfter(now)
                && campaign.endsAt().isAfter(now);
    }

    static String portfolioBudgetCurrency(List<SocialAdCampaignRecord> campaigns) {
        LinkedHashSet<String> currencies = new LinkedHashSet<>();
        campaigns.forEach(campaign -> currencies.add(campaign.budgetCurrency()));
        if (currencies.isEmpty()) {
            return "USD";
        }
        if (currencies.size() == 1) {
            return currencies.iterator().next();
        }
        return "MIXED";
    }
}
