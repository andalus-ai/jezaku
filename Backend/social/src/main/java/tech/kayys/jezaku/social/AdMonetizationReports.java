package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceRelationMetrics;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerEntryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyMetrics;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdPlacementMetrics;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BiFunction;
import java.util.function.Function;
import java.util.function.ToIntFunction;

final class AdMonetizationReports {
    private record AudienceRelation(String relation, double relevanceScore) {
    }

    private AdMonetizationReports() {
    }

    static int eventCount(List<SocialAdEventRecord> events, String eventType) {
        return (int) events.stream()
                .filter(event -> event.eventType().equals(eventType))
                .count();
    }

    static int uniqueViewerCount(List<SocialAdEventRecord> events) {
        return (int) events.stream()
                .map(SocialAdEventRecord::viewerId)
                .distinct()
                .count();
    }

    static double clickThroughRate(int impressionCount, int clickCount) {
        return impressionCount == 0 ? 0.0 : (double) clickCount / impressionCount;
    }

    static Instant lastEventAt(List<SocialAdEventRecord> events) {
        return events.stream()
                .map(SocialAdEventRecord::occurredAt)
                .max(Comparator.naturalOrder())
                .orElse(null);
    }

    static long spentCents(List<SocialAdEventRecord> events) {
        return AdMonetizationPolicy.campaignSpentCents(events);
    }

    static long remainingBudgetCents(SocialAdCampaignRecord campaign, long spentCents) {
        return AdMonetizationPolicy.campaignRemainingBudgetCents(campaign, spentCents);
    }

    static List<SocialAdPlacementMetrics> placementMetrics(List<SocialAdEventRecord> events) {
        Map<String, List<SocialAdEventRecord>> eventsByPlacement = new HashMap<>();
        for (SocialAdEventRecord event : events) {
            eventsByPlacement.computeIfAbsent(event.placement(), ignored -> new ArrayList<>()).add(event);
        }
        return eventsByPlacement.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> {
                    List<SocialAdEventRecord> placementEvents = entry.getValue();
                    int impressionCount = eventCount(placementEvents, "impression");
                    int clickCount = eventCount(placementEvents, "click");
                    int conversionCount = eventCount(placementEvents, "conversion");
                    return new SocialAdPlacementMetrics(
                            entry.getKey(),
                            spentCents(placementEvents),
                            impressionCount,
                            clickCount,
                            conversionCount,
                            uniqueViewerCount(placementEvents),
                            clickThroughRate(impressionCount, clickCount),
                            lastEventAt(placementEvents));
                })
                .toList();
    }

    static List<SocialAdDailyMetrics> dailyMetrics(
            List<SocialAdEventRecord> events,
            int windowDays,
            Instant generatedAt) {
        LocalDate endDate = LocalDate.ofInstant(generatedAt, ZoneOffset.UTC);
        LocalDate startDate = endDate.minusDays(windowDays - 1L);
        Map<LocalDate, List<SocialAdEventRecord>> eventsByDate = new HashMap<>();
        for (SocialAdEventRecord event : events) {
            LocalDate eventDate = LocalDate.ofInstant(event.occurredAt(), ZoneOffset.UTC);
            if (!eventDate.isBefore(startDate) && !eventDate.isAfter(endDate)) {
                eventsByDate.computeIfAbsent(eventDate, ignored -> new ArrayList<>()).add(event);
            }
        }
        List<SocialAdDailyMetrics> buckets = new ArrayList<>();
        for (int offset = 0; offset < windowDays; offset++) {
            LocalDate date = startDate.plusDays(offset);
            List<SocialAdEventRecord> dateEvents = eventsByDate.getOrDefault(date, List.of());
            int impressionCount = eventCount(dateEvents, "impression");
            int clickCount = eventCount(dateEvents, "click");
            buckets.add(new SocialAdDailyMetrics(
                    date.toString(),
                    spentCents(dateEvents),
                    impressionCount,
                    clickCount,
                    eventCount(dateEvents, "conversion"),
                    uniqueViewerCount(dateEvents),
                    clickThroughRate(impressionCount, clickCount)));
        }
        return buckets;
    }

    static List<SocialAdBillingLedgerEntryResponse> billingLedgerEntries(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> events,
            int limit) {
        List<SocialAdBillingLedgerEntryResponse> entries = new ArrayList<>();
        long cumulativeSpentCents = 0L;
        for (SocialAdEventRecord event : events) {
            if (entries.size() >= limit) {
                break;
            }
            long billableCents = AdMonetizationPolicy.eventCostCents(event.eventType());
            cumulativeSpentCents += billableCents;
            entries.add(new SocialAdBillingLedgerEntryResponse(
                    event.eventId(),
                    event.eventType(),
                    event.placement(),
                    event.viewerId(),
                    event.creativeContentId(),
                    event.occurredAt(),
                    event.createdAt(),
                    billableCents,
                    cumulativeSpentCents,
                    remainingBudgetCents(campaign, cumulativeSpentCents)));
        }
        return entries;
    }

    static SocialAdCampaignMetricsResponse campaignMetricsResponse(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> events,
            List<SocialAdAudienceRelationMetrics> audienceRelationMetrics,
            Instant generatedAt) {
        AdCampaignPerformance.Snapshot performance = AdCampaignPerformance.snapshot(campaign, events, generatedAt);
        return new SocialAdCampaignMetricsResponse(
                campaign.campaignId(),
                campaign.advertiserId(),
                campaign.status(),
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
                placementMetrics(events),
                audienceRelationMetrics,
                performance.budgetPacing(),
                performance.lastEventAt());
    }

    static SocialAdDailyReportResponse campaignDailyReportResponse(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> events,
            int windowDays,
            Instant generatedAt) {
        return new SocialAdDailyReportResponse(
                campaign.campaignId(),
                campaign.advertiserId(),
                campaign.budgetCurrency(),
                windowDays,
                generatedAt,
                dailyMetrics(events, windowDays, generatedAt));
    }

    static SocialAdBillingLedgerResponse billingLedgerResponse(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> billingEvents,
            int limit) {
        long spentCents = AdCampaignPerformance.spentCents(billingEvents);
        long remainingBudgetCents = AdCampaignPerformance.remainingBudgetCents(campaign, spentCents);
        List<SocialAdBillingLedgerEntryResponse> entries = billingLedgerEntries(campaign, billingEvents, limit);
        return new SocialAdBillingLedgerResponse(
                campaign.campaignId(),
                campaign.advertiserId(),
                campaign.budgetCurrency(),
                campaign.budgetCents(),
                spentCents,
                remainingBudgetCents,
                remainingBudgetCents == 0,
                entries.size(),
                limit,
                entries);
    }

    static SocialAdAdvertiserDailyReportResponse advertiserDailyReportResponse(
            String advertiserId,
            String status,
            int limit,
            int windowDays,
            Instant generatedAt,
            List<SocialAdCampaignRecord> campaigns,
            List<SocialAdEventRecord> events) {
        return new SocialAdAdvertiserDailyReportResponse(
                advertiserId,
                status,
                AdCampaignPerformance.portfolioBudgetCurrency(campaigns),
                campaigns.size(),
                limit,
                windowDays,
                generatedAt,
                dailyMetrics(events, windowDays, generatedAt));
    }

    static List<SocialAdAudienceRelationMetrics> audienceRelationMetrics(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> events,
            BiFunction<SocialAdCampaignRecord, String, SocialAdAudienceCandidate> audienceResolver) {
        return audienceRelationMetrics(events, Map.of(campaign.campaignId(), campaign), audienceResolver);
    }

    static List<SocialAdAudienceRelationMetrics> audienceRelationMetrics(
            List<SocialAdEventRecord> events,
            Map<String, SocialAdCampaignRecord> campaignsById,
            BiFunction<SocialAdCampaignRecord, String, SocialAdAudienceCandidate> audienceResolver) {
        return audienceRelationMetrics(events, event -> {
            SocialAdCampaignRecord campaign = campaignsById.get(event.campaignId());
            SocialAdAudienceCandidate candidate = campaign == null
                    ? null
                    : audienceResolver.apply(campaign, event.viewerId());
            if (candidate == null) {
                return null;
            }
            return new AudienceRelation(candidate.primaryRelation(), candidate.relevanceScore());
        }, AdMonetizationReports::audienceMetricRelationPriority);
    }

    private static List<SocialAdAudienceRelationMetrics> audienceRelationMetrics(
            List<SocialAdEventRecord> events,
            Function<SocialAdEventRecord, AudienceRelation> relationResolver,
            ToIntFunction<String> relationPriority) {
        Map<String, List<SocialAdEventRecord>> eventsByRelation = new HashMap<>();
        Map<String, List<Double>> relevanceScoresByRelation = new HashMap<>();
        for (SocialAdEventRecord event : events) {
            AudienceRelation relation = relationResolver.apply(event);
            String relationName = relation == null ? "unmatched" : relation.relation();
            eventsByRelation.computeIfAbsent(relationName, ignored -> new ArrayList<>()).add(event);
            relevanceScoresByRelation.computeIfAbsent(relationName, ignored -> new ArrayList<>())
                    .add(relation == null ? 0.0 : relation.relevanceScore());
        }
        return eventsByRelation.entrySet().stream()
                .sorted(Comparator.comparingInt((Map.Entry<String, List<SocialAdEventRecord>> entry) ->
                        relationPriority.applyAsInt(entry.getKey()))
                        .thenComparing(Map.Entry::getKey))
                .map(entry -> {
                    List<SocialAdEventRecord> relationEvents = entry.getValue();
                    int impressionCount = eventCount(relationEvents, "impression");
                    int clickCount = eventCount(relationEvents, "click");
                    int conversionCount = eventCount(relationEvents, "conversion");
                    double averageRelevanceScore = relevanceScoresByRelation.getOrDefault(entry.getKey(), List.of())
                            .stream()
                            .mapToDouble(Double::doubleValue)
                            .average()
                            .orElse(0.0);
                    return new SocialAdAudienceRelationMetrics(
                            entry.getKey(),
                            spentCents(relationEvents),
                            impressionCount,
                            clickCount,
                            conversionCount,
                            uniqueViewerCount(relationEvents),
                            clickThroughRate(impressionCount, clickCount),
                            averageRelevanceScore,
                            lastEventAt(relationEvents));
                })
                .toList();
    }

    private static int audienceMetricRelationPriority(String relation) {
        if ("unmatched".equals(relation)) {
            return 1_000;
        }
        return AdAudiencePlanner.metricRelationPriority(relation);
    }
}
