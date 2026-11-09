package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreativeReviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignStatusUpdateRequest;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdCampaignManagementModel {
    private final AdMonetizationReadModel readModel;
    private final AdMonetizationWriteModel writeModel;
    private final int maxCampaignListLimit;
    private final Supplier<Instant> now;

    AdCampaignManagementModel(
            AdMonetizationReadModel readModel,
            AdMonetizationWriteModel writeModel,
            int maxCampaignListLimit,
            Supplier<Instant> now) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.maxCampaignListLimit = maxCampaignListLimit;
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialAdCampaignListResponse campaigns(String advertiserId, String status, Integer limit) {
        String advertiser = requireText(advertiserId, "advertiserId");
        String normalizedStatus = AdCampaignDrafts.statusFilter(status);
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxCampaignListLimit, "limit");
        List<SocialAdCampaignRecord> campaigns = readModel.campaignsForAdvertiser(
                advertiser,
                normalizedStatus,
                normalizedLimit);
        return AdCampaignLifecycle.listResponse(advertiser, normalizedStatus, normalizedLimit, campaigns);
    }

    SocialAdCampaignResponse campaign(String campaignId, String advertiserId) {
        return AdCampaignLifecycle.response(readModel.requireCampaignForAdvertiser(campaignId, advertiserId));
    }

    SocialAdCampaignResponse updateStatus(String campaignId, SocialAdCampaignStatusUpdateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        SocialAdCampaignRecord campaign = readModel.requireCampaignForAdvertiser(
                campaignId,
                request.advertiserId());
        SocialAdCampaignRecord updated = AdCampaignLifecycle.updateStatus(campaign, request.status(), now.get());
        return AdCampaignLifecycle.response(writeModel.saveCampaign(updated));
    }

    SocialAdCampaignResponse updateCreativeReview(
            String campaignId,
            SocialAdCampaignCreativeReviewRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        SocialAdCampaignRecord campaign = readModel.requireCampaignForAdvertiser(
                campaignId,
                request.advertiserId());
        SocialAdCampaignRecord updated = AdCampaignLifecycle.updateCreativeReview(
                campaign,
                request.status(),
                request.reason(),
                now.get());
        return AdCampaignLifecycle.response(writeModel.saveCampaign(updated));
    }
}
