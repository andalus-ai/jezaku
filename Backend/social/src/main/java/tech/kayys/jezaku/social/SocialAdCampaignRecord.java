package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;

/**
 * Stores an advertiser campaign configuration derived from social graph targeting inputs.
 */
record SocialAdCampaignRecord(
        String campaignId,
        String advertiserId,
        String name,
        String objective,
        String status,
        String creativeContentId,
        String creativeReviewStatus,
        String creativeReviewReason,
        Instant creativeReviewedAt,
        String budgetCurrency,
        long budgetCents,
        Instant startsAt,
        Instant endsAt,
        int maxDepth,
        int audienceLimit,
        int estimatedReach,
        List<String> relationScopes,
        List<String> targetTags,
        List<String> targetGroupIds,
        List<String> targetCommunityIds,
        Instant createdAt,
        Instant updatedAt) {
    SocialAdCampaignRecord withStatus(String status, Instant updatedAt) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
                name,
                objective,
                status,
                creativeContentId,
                creativeReviewStatus,
                creativeReviewReason,
                creativeReviewedAt,
                budgetCurrency,
                budgetCents,
                startsAt,
                endsAt,
                maxDepth,
                audienceLimit,
                estimatedReach,
                relationScopes,
                targetTags,
                targetGroupIds,
                targetCommunityIds,
                createdAt,
                updatedAt);
    }

    SocialAdCampaignRecord withCreativeReview(
            String creativeReviewStatus,
            String creativeReviewReason,
            Instant creativeReviewedAt,
            Instant updatedAt) {
        return new SocialAdCampaignRecord(
                campaignId,
                advertiserId,
                name,
                objective,
                status,
                creativeContentId,
                creativeReviewStatus,
                creativeReviewReason,
                creativeReviewedAt,
                budgetCurrency,
                budgetCents,
                startsAt,
                endsAt,
                maxDepth,
                audienceLimit,
                estimatedReach,
                relationScopes,
                targetTags,
                targetGroupIds,
                targetCommunityIds,
                createdAt,
                updatedAt);
    }
}
