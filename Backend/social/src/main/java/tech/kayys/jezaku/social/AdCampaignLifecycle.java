package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;

import java.time.Instant;
import java.util.List;

import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;

final class AdCampaignLifecycle {
    private AdCampaignLifecycle() {
    }

    static SocialAdCampaignRecord updateStatus(
            SocialAdCampaignRecord campaign,
            String requestedStatus,
            Instant updatedAt) {
        return campaign.withStatus(AdCampaignDrafts.status(requestedStatus), updatedAt);
    }

    static SocialAdCampaignRecord updateCreativeReview(
            SocialAdCampaignRecord campaign,
            String requestedStatus,
            String requestedReason,
            Instant updatedAt) {
        String reviewStatus = AdMonetizationPolicy.creativeReviewStatus(requestedStatus);
        String reviewReason = optionalTextMaxLength(requestedReason, "", "reason", 500);
        Instant reviewedAt = "pending_review".equals(reviewStatus) ? null : updatedAt;
        return campaign.withCreativeReview(reviewStatus, reviewReason, reviewedAt, updatedAt);
    }

    static SocialAdCampaignListResponse listResponse(
            String advertiserId,
            String status,
            int limit,
            List<SocialAdCampaignRecord> campaigns) {
        List<SocialAdCampaignResponse> responses = campaigns.stream()
                .map(AdCampaignLifecycle::response)
                .toList();
        return new SocialAdCampaignListResponse(
                advertiserId,
                status,
                responses.size(),
                limit,
                responses);
    }

    static SocialAdCampaignResponse response(SocialAdCampaignRecord campaign) {
        return new SocialAdCampaignResponse(
                campaign.campaignId(),
                campaign.advertiserId(),
                campaign.name(),
                campaign.objective(),
                campaign.status(),
                campaign.creativeContentId(),
                campaign.creativeReviewStatus(),
                campaign.creativeReviewReason(),
                campaign.creativeReviewedAt(),
                campaign.budgetCurrency(),
                campaign.budgetCents(),
                campaign.startsAt(),
                campaign.endsAt(),
                campaign.maxDepth(),
                campaign.audienceLimit(),
                campaign.estimatedReach(),
                campaign.relationScopes(),
                campaign.targetTags(),
                campaign.targetGroupIds(),
                campaign.targetCommunityIds(),
                campaign.createdAt(),
                campaign.updatedAt());
    }
}
