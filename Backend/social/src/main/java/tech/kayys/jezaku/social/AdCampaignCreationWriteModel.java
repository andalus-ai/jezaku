package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;

import java.time.Instant;
import java.util.Objects;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdCampaignCreationWriteModel {
    private final AdMonetizationReadModel readModel;
    private final AdMonetizationWriteModel writeModel;
    private final AdSocialAccess socialAccess;
    private final AdAudiencePreviewReadModel audiencePreviewReadModel;
    private final Supplier<String> fallbackCampaignId;
    private final Supplier<Instant> now;

    AdCampaignCreationWriteModel(
            AdMonetizationReadModel readModel,
            AdMonetizationWriteModel writeModel,
            AdSocialAccess socialAccess,
            AdAudiencePreviewReadModel audiencePreviewReadModel,
            Supplier<String> fallbackCampaignId,
            Supplier<Instant> now) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.socialAccess = Objects.requireNonNull(socialAccess, "socialAccess");
        this.audiencePreviewReadModel = Objects.requireNonNull(
                audiencePreviewReadModel,
                "audiencePreviewReadModel");
        this.fallbackCampaignId = Objects.requireNonNull(fallbackCampaignId, "fallbackCampaignId");
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialAdCampaignResponse create(SocialAdCampaignCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String campaignId = AdCampaignDrafts.campaignId(request.campaignId(), fallbackCampaignId);
        if (readModel.campaign(campaignId) != null) {
            throw new WebApplicationException("Ad campaign already exists: " + campaignId, Response.Status.CONFLICT);
        }
        String advertiser = requireText(request.advertiserId(), "advertiserId");
        String objective = AdMonetizationPolicy.objective(request.objective());
        String creativeContentId = socialAccess.creativeContentId(advertiser, request.creativeContentId());
        int maxDepth = audiencePreviewReadModel.maxDepth(request.maxDepth());
        int audienceLimit = audiencePreviewReadModel.audienceLimit(request.audienceLimit(), "audienceLimit");
        AdCampaignDrafts.DraftTerms draft = AdCampaignDrafts.terms(
                campaignId,
                request,
                advertiser,
                objective,
                creativeContentId,
                maxDepth,
                audienceLimit,
                now.get());
        AdAudiencePreviewReadModel.Targeting targeting = audiencePreviewReadModel.targeting(
                request.relationScopes(),
                request.targetTags(),
                request.targetGroupIds(),
                request.targetCommunityIds());
        SocialAdAudiencePreviewResponse preview = audiencePreviewReadModel.preview(
                advertiser,
                objective,
                maxDepth,
                audienceLimit,
                targeting);
        SocialAdCampaignRecord campaign = AdCampaignDrafts.record(
                draft,
                preview.estimatedReach(),
                targeting.relationScopes(),
                targeting.targetTags(),
                targeting.targetGroupIds(),
                targeting.targetCommunityIds());
        return AdCampaignLifecycle.response(writeModel.saveCampaign(campaign));
    }
}
