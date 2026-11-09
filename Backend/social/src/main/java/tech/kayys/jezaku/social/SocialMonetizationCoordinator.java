package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreativeReviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignStatusUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;
import java.util.function.BiFunction;

/**
 * Coordinates ad monetization use cases from social graph state, access policy, and ad workflow models.
 */
final class SocialMonetizationCoordinator {
    private static final int DEFAULT_AUDIENCE_LIMIT = 100;
    private static final int DEFAULT_CAMPAIGN_LIST_LIMIT = 100;
    private static final int DEFAULT_DELIVERY_LIMIT = 20;
    private static final int DEFAULT_BILLING_LEDGER_LIMIT = 200;
    private static final int DEFAULT_DAILY_REPORT_DAYS = 90;
    private static final int DEFAULT_IMPRESSIONS_PER_VIEWER_24H = 3;
    private static final long DEFAULT_FREQUENCY_WINDOW_SECONDS = 86_400L;

    private final AdAudiencePreviewReadModel audiencePreviewReadModel;
    private final AdCampaignCreationWriteModel campaignCreationWriteModel;
    private final AdCampaignManagementModel campaignManagementModel;
    private final AdDeliveryReadModel deliveryReadModel;
    private final AdEventTrackingWriteModel eventTrackingWriteModel;
    private final AdCampaignReportingReadModel campaignReportingReadModel;

    SocialMonetizationCoordinator(
            SocialGraphRepository repository,
            SocialGraphEntityResolver entityResolver,
            SocialRelationshipPolicy relationshipPolicy,
            SocialCircleMembershipIndex circleMembershipIndex,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext,
            SocialContentAccessResolver contentAccessResolver,
            SocialUserStatsResolver userStatsResolver,
            SocialPresentationGateway presentationGateway,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialGraphEntityResolver resolvedEntityResolver = Objects.requireNonNull(entityResolver, "entityResolver");
        SocialRelationshipPolicy resolvedRelationshipPolicy =
                Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        SocialCircleMembershipIndex resolvedCircleMembershipIndex =
                Objects.requireNonNull(circleMembershipIndex, "circleMembershipIndex");
        BiFunction<String, String, SocialRelationshipContextResponse> resolvedRelationshipContext =
                Objects.requireNonNull(relationshipContext, "relationshipContext");
        SocialContentAccessResolver resolvedContentAccessResolver =
                Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        SocialUserStatsResolver resolvedUserStatsResolver =
                Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        SocialPresentationGateway resolvedPresentationGateway =
                Objects.requireNonNull(presentationGateway, "presentationGateway");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        AdMonetizationStore monetizationStore = new SocialGraphAdMonetizationStore(resolvedRepository);
        AdMonetizationReadModel monetizationReadModel = new AdMonetizationReadModel(
                monetizationStore,
                resolvedLimits.frequencyWindowSeconds());
        AdMonetizationWriteModel monetizationWriteModel = new AdMonetizationWriteModel(monetizationStore);
        AdSocialAccess socialAccess = new AdSocialAccess(
                resolvedEntityResolver::requireGroup,
                resolvedEntityResolver::requireCommunity,
                resolvedCircleMembershipIndex::groupMember,
                resolvedCircleMembershipIndex::communityMember,
                resolvedEntityResolver::requireContent,
                resolvedRepository::content,
                resolvedContentAccessResolver::audience,
                resolvedContentAccessResolver::hidden);
        AdAudienceGraphSignals audienceGraphSignals = new SocialAdAudienceGraphSignals(
                resolvedRelationshipContext,
                new SocialConnectionIndex(resolvedRepository),
                resolvedCircleMembershipIndex,
                new SocialUserInterestIndex(resolvedRepository),
                resolvedUserStatsResolver::visibleContentCount,
                resolvedPresentationGateway::userLabel);
        AdAudienceCandidateResolver audienceCandidateResolver =
                new AdAudienceCandidateResolver(audienceGraphSignals);
        this.audiencePreviewReadModel = new AdAudiencePreviewReadModel(
                socialAccess,
                new SocialGraphUserIndex(resolvedRepository),
                audienceCandidateResolver,
                resolvedRelationshipPolicy::blockedEitherWay,
                resolvedLimits.audienceLimit());
        this.campaignCreationWriteModel = new AdCampaignCreationWriteModel(
                monetizationReadModel,
                monetizationWriteModel,
                socialAccess,
                audiencePreviewReadModel,
                () -> "ad_campaign_" + UUID.randomUUID(),
                Instant::now);
        this.campaignManagementModel = new AdCampaignManagementModel(
                monetizationReadModel,
                monetizationWriteModel,
                resolvedLimits.campaignListLimit(),
                Instant::now);
        this.deliveryReadModel = new AdDeliveryReadModel(
                monetizationReadModel,
                socialAccess,
                audienceCandidateResolver,
                resolvedRelationshipPolicy::blockedEitherWay,
                resolvedLimits.deliveryLimit(),
                resolvedLimits.maxImpressionsPerViewer24h(),
                Instant::now);
        this.eventTrackingWriteModel = new AdEventTrackingWriteModel(
                monetizationReadModel,
                monetizationWriteModel,
                socialAccess,
                audienceCandidateResolver,
                resolvedRelationshipPolicy::blockedEitherWay,
                () -> "ad_event_" + UUID.randomUUID(),
                Instant::now);
        this.campaignReportingReadModel = new AdCampaignReportingReadModel(
                monetizationReadModel,
                audienceCandidateResolver,
                resolvedLimits.campaignListLimit(),
                resolvedLimits.billingLedgerLimit(),
                resolvedLimits.dailyReportDays(),
                Instant::now);
    }

    SocialAdAudiencePreviewResponse adAudiencePreview(SocialAdAudiencePreviewRequest request) {
        return audiencePreviewReadModel.preview(request);
    }

    SocialAdCampaignResponse createAdCampaign(SocialAdCampaignCreateRequest request) {
        return campaignCreationWriteModel.create(request);
    }

    SocialAdCampaignListResponse adCampaigns(String advertiserId, String status, Integer limit) {
        return campaignManagementModel.campaigns(advertiserId, status, limit);
    }

    SocialAdCampaignResponse adCampaign(String campaignId, String advertiserId) {
        return campaignManagementModel.campaign(campaignId, advertiserId);
    }

    SocialAdCampaignResponse updateAdCampaignStatus(
            String campaignId,
            SocialAdCampaignStatusUpdateRequest request) {
        return campaignManagementModel.updateStatus(campaignId, request);
    }

    SocialAdCampaignResponse updateAdCampaignCreativeReview(
            String campaignId,
            SocialAdCampaignCreativeReviewRequest request) {
        return campaignManagementModel.updateCreativeReview(campaignId, request);
    }

    SocialAdDeliveryResponse adDelivery(String viewerId, String placement, Integer limit) {
        return deliveryReadModel.delivery(viewerId, placement, limit);
    }

    SocialAdEventResponse createAdEvent(SocialAdEventCreateRequest request) {
        return eventTrackingWriteModel.create(request);
    }

    SocialAdCampaignMetricsResponse adCampaignMetrics(String campaignId, String advertiserId) {
        return campaignReportingReadModel.campaignMetrics(campaignId, advertiserId);
    }

    SocialAdDailyReportResponse adCampaignDailyReport(String campaignId, String advertiserId, Integer days) {
        return campaignReportingReadModel.campaignDailyReport(campaignId, advertiserId, days);
    }

    SocialAdBillingLedgerResponse adCampaignBillingLedger(String campaignId, String advertiserId, Integer limit) {
        return campaignReportingReadModel.campaignBillingLedger(campaignId, advertiserId, limit);
    }

    SocialAdAdvertiserDashboardResponse adAdvertiserDashboard(String advertiserId, String status, Integer limit) {
        return campaignReportingReadModel.advertiserDashboard(advertiserId, status, limit);
    }

    SocialAdAdvertiserDailyReportResponse adAdvertiserDailyReport(
            String advertiserId,
            String status,
            Integer days,
            Integer limit) {
        return campaignReportingReadModel.advertiserDailyReport(advertiserId, status, days, limit);
    }

    static Limits defaultLimits() {
        return new Limits(
                DEFAULT_AUDIENCE_LIMIT,
                DEFAULT_CAMPAIGN_LIST_LIMIT,
                DEFAULT_DELIVERY_LIMIT,
                DEFAULT_BILLING_LEDGER_LIMIT,
                DEFAULT_DAILY_REPORT_DAYS,
                DEFAULT_IMPRESSIONS_PER_VIEWER_24H,
                DEFAULT_FREQUENCY_WINDOW_SECONDS);
    }

    /**
     * Defines operational limits for monetization endpoint orchestration.
     */
    record Limits(
            int audienceLimit,
            int campaignListLimit,
            int deliveryLimit,
            int billingLedgerLimit,
            int dailyReportDays,
            int maxImpressionsPerViewer24h,
            long frequencyWindowSeconds) {
    }
}
