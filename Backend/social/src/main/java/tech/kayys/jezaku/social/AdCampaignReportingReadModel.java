package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceRelationMetrics;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyReportResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Supplier;
import java.util.stream.Collectors;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdCampaignReportingReadModel {
    private final AdMonetizationReadModel readModel;
    private final AdAudienceCandidateResolver audienceCandidateResolver;
    private final int maxCampaignListLimit;
    private final int maxBillingLedgerLimit;
    private final int maxDailyReportDays;
    private final Supplier<Instant> now;

    AdCampaignReportingReadModel(
            AdMonetizationReadModel readModel,
            AdAudienceCandidateResolver audienceCandidateResolver,
            int maxCampaignListLimit,
            int maxBillingLedgerLimit,
            int maxDailyReportDays,
            Supplier<Instant> now) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.audienceCandidateResolver = Objects.requireNonNull(
                audienceCandidateResolver,
                "audienceCandidateResolver");
        this.maxCampaignListLimit = maxCampaignListLimit;
        this.maxBillingLedgerLimit = maxBillingLedgerLimit;
        this.maxDailyReportDays = maxDailyReportDays;
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialAdCampaignMetricsResponse campaignMetrics(String campaignId, String advertiserId) {
        SocialAdCampaignRecord campaign = readModel.requireCampaignForAdvertiser(campaignId, advertiserId);
        List<SocialAdEventRecord> events = readModel.eventsForCampaign(campaign.campaignId());
        return AdMonetizationReports.campaignMetricsResponse(
                campaign,
                events,
                campaignRelationMetrics(campaign, events),
                now.get());
    }

    SocialAdDailyReportResponse campaignDailyReport(String campaignId, String advertiserId, Integer days) {
        SocialAdCampaignRecord campaign = readModel.requireCampaignForAdvertiser(campaignId, advertiserId);
        int windowDays = normalizeReportDays(days);
        Instant generatedAt = now.get();
        List<SocialAdEventRecord> events = readModel.eventsForCampaign(campaign.campaignId());
        return AdMonetizationReports.campaignDailyReportResponse(campaign, events, windowDays, generatedAt);
    }

    SocialAdBillingLedgerResponse campaignBillingLedger(String campaignId, String advertiserId, Integer limit) {
        SocialAdCampaignRecord campaign = readModel.requireCampaignForAdvertiser(campaignId, advertiserId);
        int normalizedLimit = normalizeBillingLimit(limit);
        List<SocialAdEventRecord> events = readModel.billingEventsForCampaign(campaign.campaignId());
        return AdMonetizationReports.billingLedgerResponse(campaign, events, normalizedLimit);
    }

    SocialAdAdvertiserDashboardResponse advertiserDashboard(String advertiserId, String status, Integer limit) {
        String advertiser = requireText(advertiserId, "advertiserId");
        String normalizedStatus = AdCampaignDrafts.statusFilter(status);
        int normalizedLimit = normalizeCampaignListLimit(limit);
        Instant generatedAt = now.get();
        List<SocialAdCampaignRecord> campaigns = readModel.campaignsForAdvertiser(
                advertiser,
                normalizedStatus,
                normalizedLimit);
        return AdAdvertiserDashboard.response(
                advertiser,
                normalizedStatus,
                normalizedLimit,
                campaigns,
                campaign -> readModel.eventsForCampaign(campaign.campaignId()),
                this::campaignRelationMetrics,
                this::portfolioRelationMetrics,
                generatedAt);
    }

    SocialAdAdvertiserDailyReportResponse advertiserDailyReport(
            String advertiserId,
            String status,
            Integer days,
            Integer limit) {
        String advertiser = requireText(advertiserId, "advertiserId");
        String normalizedStatus = AdCampaignDrafts.statusFilter(status);
        int normalizedLimit = normalizeCampaignListLimit(limit);
        int windowDays = normalizeReportDays(days);
        Instant generatedAt = now.get();
        List<SocialAdCampaignRecord> campaigns = readModel.campaignsForAdvertiser(
                advertiser,
                normalizedStatus,
                normalizedLimit);
        Set<String> campaignIds = campaigns.stream()
                .map(SocialAdCampaignRecord::campaignId)
                .collect(Collectors.toSet());
        List<SocialAdEventRecord> events = readModel.eventsForCampaigns(campaignIds);
        return AdMonetizationReports.advertiserDailyReportResponse(
                advertiser,
                normalizedStatus,
                normalizedLimit,
                windowDays,
                generatedAt,
                campaigns,
                events);
    }

    private int normalizeCampaignListLimit(Integer limit) {
        return normalizeBoundedInt(limit, 20, 1, maxCampaignListLimit, "limit");
    }

    private int normalizeBillingLimit(Integer limit) {
        return normalizeBoundedInt(limit, 100, 1, maxBillingLedgerLimit, "limit");
    }

    private int normalizeReportDays(Integer days) {
        return normalizeBoundedInt(days, 7, 1, maxDailyReportDays, "days");
    }

    private List<SocialAdAudienceRelationMetrics> campaignRelationMetrics(
            SocialAdCampaignRecord campaign,
            List<SocialAdEventRecord> events) {
        return AdMonetizationReports.audienceRelationMetrics(
                campaign,
                events,
                audienceCandidateResolver::campaignCandidate);
    }

    private List<SocialAdAudienceRelationMetrics> portfolioRelationMetrics(
            List<SocialAdEventRecord> events,
            Map<String, SocialAdCampaignRecord> campaignsById) {
        return AdMonetizationReports.audienceRelationMetrics(
                events,
                campaignsById,
                audienceCandidateResolver::campaignCandidate);
    }
}
