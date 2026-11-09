package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
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

/**
 * Provides asynchronous monetization endpoints while the shared social service owns cross-feature context.
 */
@ApplicationScoped
public class SocialMonetizationService {
    private final SocialService socialService;

    @Inject
    public SocialMonetizationService(SocialService socialService) {
        this.socialService = socialService;
    }

    public Uni<SocialAdAudiencePreviewResponse> adAudiencePreview(SocialAdAudiencePreviewRequest request) {
        return socialService.adAudiencePreview(request);
    }

    public Uni<SocialAdCampaignResponse> createAdCampaign(SocialAdCampaignCreateRequest request) {
        return socialService.createAdCampaign(request);
    }

    public Uni<SocialAdCampaignListResponse> adCampaigns(String advertiserId, String status, Integer limit) {
        return socialService.adCampaigns(advertiserId, status, limit);
    }

    public Uni<SocialAdAdvertiserDashboardResponse> adAdvertiserDashboard(
            String advertiserId,
            String status,
            Integer limit) {
        return socialService.adAdvertiserDashboard(advertiserId, status, limit);
    }

    public Uni<SocialAdAdvertiserDailyReportResponse> adAdvertiserDailyReport(
            String advertiserId,
            String status,
            Integer days,
            Integer limit) {
        return socialService.adAdvertiserDailyReport(advertiserId, status, days, limit);
    }

    public Uni<SocialAdCampaignResponse> adCampaign(String campaignId, String advertiserId) {
        return socialService.adCampaign(campaignId, advertiserId);
    }

    public Uni<SocialAdCampaignMetricsResponse> adCampaignMetrics(String campaignId, String advertiserId) {
        return socialService.adCampaignMetrics(campaignId, advertiserId);
    }

    public Uni<SocialAdDailyReportResponse> adCampaignDailyReport(
            String campaignId,
            String advertiserId,
            Integer days) {
        return socialService.adCampaignDailyReport(campaignId, advertiserId, days);
    }

    public Uni<SocialAdBillingLedgerResponse> adCampaignBillingLedger(
            String campaignId,
            String advertiserId,
            Integer limit) {
        return socialService.adCampaignBillingLedger(campaignId, advertiserId, limit);
    }

    public Uni<SocialAdCampaignResponse> updateAdCampaignStatus(
            String campaignId,
            SocialAdCampaignStatusUpdateRequest request) {
        return socialService.updateAdCampaignStatus(campaignId, request);
    }

    public Uni<SocialAdCampaignResponse> updateAdCampaignCreativeReview(
            String campaignId,
            SocialAdCampaignCreativeReviewRequest request) {
        return socialService.updateAdCampaignCreativeReview(campaignId, request);
    }

    public Uni<SocialAdDeliveryResponse> adDelivery(String viewerId, String placement, Integer limit) {
        return socialService.adDelivery(viewerId, placement, limit);
    }

    public Uni<SocialAdEventResponse> createAdEvent(SocialAdEventCreateRequest request) {
        return socialService.createAdEvent(request);
    }
}
