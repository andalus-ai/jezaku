package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.function.BiFunction;
import java.util.function.BiPredicate;
import java.util.function.ToLongFunction;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;

final class AdDeliveryPlanner {
    private AdDeliveryPlanner() {
    }

    @FunctionalInterface
    interface RecentImpressionCounter {
        int count(String campaignId, String viewerId, Instant now);
    }

    static SocialAdDeliveryResponse response(
            String viewerId,
            String placement,
            int limit,
            Instant now,
            List<SocialAdCampaignRecord> campaigns,
            int maxImpressionsPerViewer,
            ToLongFunction<SocialAdCampaignRecord> remainingBudgetCents,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<SocialAdCampaignRecord, String> creativeVisibleToViewer,
            BiFunction<SocialAdCampaignRecord, String, SocialAdAudienceCandidate> audienceResolver,
            RecentImpressionCounter recentImpressions) {
        List<SocialAdDeliveryCandidate> candidates = campaigns.stream()
                .map(campaign -> candidate(
                        campaign,
                        viewerId,
                        placement,
                        now,
                        maxImpressionsPerViewer,
                        remainingBudgetCents,
                        blockedEitherWay,
                        creativeVisibleToViewer,
                        audienceResolver,
                        recentImpressions))
                .filter(candidate -> candidate != null)
                .sorted(Comparator.comparingDouble(SocialAdDeliveryCandidate::deliveryScore).reversed()
                        .thenComparing(SocialAdDeliveryCandidate::campaignId))
                .limit(limit)
                .toList();
        return new SocialAdDeliveryResponse(
                viewerId,
                placement,
                candidates.size(),
                limit,
                now,
                candidates);
    }

    static SocialAdDeliveryCandidate candidate(
            SocialAdCampaignRecord campaign,
            String viewerId,
            String placement,
            Instant now,
            int maxImpressionsPerViewer,
            ToLongFunction<SocialAdCampaignRecord> remainingBudgetCents,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<SocialAdCampaignRecord, String> creativeVisibleToViewer,
            BiFunction<SocialAdCampaignRecord, String, SocialAdAudienceCandidate> audienceResolver,
            RecentImpressionCounter recentImpressions) {
        if (!deliverable(
                campaign,
                viewerId,
                now,
                maxImpressionsPerViewer,
                remainingBudgetCents,
                blockedEitherWay,
                creativeVisibleToViewer,
                recentImpressions)) {
            return null;
        }
        SocialAdAudienceCandidate audienceCandidate = audienceResolver.apply(campaign, viewerId);
        if (audienceCandidate == null) {
            return null;
        }
        return new SocialAdDeliveryCandidate(
                campaign.campaignId(),
                campaign.advertiserId(),
                campaign.name(),
                campaign.objective(),
                placement,
                campaign.creativeContentId(),
                audienceCandidate.primaryRelation(),
                audienceCandidate.connectionDepth(),
                audienceCandidate.relevanceScore(),
                deliveryScore(campaign, audienceCandidate, placement, now),
                audienceCandidate.matchedTags(),
                audienceCandidate.matchedGroupIds(),
                audienceCandidate.matchedCommunityIds(),
                deliveryReasons(campaign, audienceCandidate, placement),
                campaign.startsAt(),
                campaign.endsAt());
    }

    private static boolean deliverable(
            SocialAdCampaignRecord campaign,
            String viewerId,
            Instant now,
            int maxImpressionsPerViewer,
            ToLongFunction<SocialAdCampaignRecord> remainingBudgetCents,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<SocialAdCampaignRecord, String> creativeVisibleToViewer,
            RecentImpressionCounter recentImpressions) {
        return "scheduled".equals(campaign.status())
                && !campaign.advertiserId().equals(viewerId)
                && !campaign.startsAt().isAfter(now)
                && campaign.endsAt().isAfter(now)
                && AdMonetizationPolicy.creativeApproved(campaign)
                && remainingBudgetCents.applyAsLong(campaign) > 0
                && !blockedEitherWay.test(campaign.advertiserId(), viewerId)
                && creativeVisibleToViewer.test(campaign, viewerId)
                && recentImpressions.count(campaign.campaignId(), viewerId, now) < maxImpressionsPerViewer;
    }

    private static double deliveryScore(
            SocialAdCampaignRecord campaign,
            SocialAdAudienceCandidate audienceCandidate,
            String placement,
            Instant now) {
        double score = audienceCandidate.relevanceScore()
                + objectiveDeliveryBoost(campaign.objective())
                + placementDeliveryBoost(placement)
                + campaignFreshnessBoost(campaign, now);
        return Math.min(100.0, score);
    }

    private static double objectiveDeliveryBoost(String objective) {
        return switch (objective) {
            case "engagement" -> 6.0;
            case "traffic" -> 5.0;
            case "conversion" -> 4.0;
            default -> 3.0;
        };
    }

    private static double placementDeliveryBoost(String placement) {
        return switch (placement) {
            case "camera" -> 4.0;
            case "story" -> 3.0;
            case "minimap" -> 2.0;
            default -> 1.0;
        };
    }

    private static double campaignFreshnessBoost(SocialAdCampaignRecord campaign, Instant now) {
        long campaignAgeSeconds = Math.max(0, now.getEpochSecond() - campaign.updatedAt().getEpochSecond());
        double ageDays = campaignAgeSeconds / 86_400.0;
        return Math.max(0.0, 3.0 - Math.min(3.0, ageDays));
    }

    private static List<String> deliveryReasons(
            SocialAdCampaignRecord campaign,
            SocialAdAudienceCandidate audienceCandidate,
            String placement) {
        LinkedHashSet<String> reasons = new LinkedHashSet<>(audienceCandidate.reasons());
        reasons.add("campaign_scheduled");
        reasons.add("placement:" + placement);
        reasons.add("objective:" + campaign.objective());
        reasons.add("creative_review:" + campaign.creativeReviewStatus());
        if (!campaign.creativeContentId().isEmpty()) {
            reasons.add("creative_visible");
        }
        return List.copyOf(reasons);
    }
}
