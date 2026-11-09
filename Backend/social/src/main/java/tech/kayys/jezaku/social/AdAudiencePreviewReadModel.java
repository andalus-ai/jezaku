package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;

import java.util.Objects;
import java.util.Set;
import java.util.function.BiPredicate;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdAudiencePreviewReadModel {
    private final AdSocialAccess socialAccess;
    private final SocialGraphUserIndex userIndex;
    private final AdAudienceCandidateResolver candidateResolver;
    private final BiPredicate<String, String> blockedEitherWay;
    private final int maxAudienceLimit;

    AdAudiencePreviewReadModel(
            AdSocialAccess socialAccess,
            SocialGraphUserIndex userIndex,
            AdAudienceCandidateResolver candidateResolver,
            BiPredicate<String, String> blockedEitherWay,
            int maxAudienceLimit) {
        this.socialAccess = Objects.requireNonNull(socialAccess, "socialAccess");
        this.userIndex = Objects.requireNonNull(userIndex, "userIndex");
        this.candidateResolver = Objects.requireNonNull(candidateResolver, "candidateResolver");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
        this.maxAudienceLimit = maxAudienceLimit;
    }

    SocialAdAudiencePreviewResponse preview(SocialAdAudiencePreviewRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        return preview(
                requireText(request.advertiserId(), "advertiserId"),
                AdMonetizationPolicy.objective(request.objective()),
                maxDepth(request.maxDepth()),
                audienceLimit(request.limit(), "limit"),
                targeting(
                        request.relationScopes(),
                        request.targetTags(),
                        request.targetGroupIds(),
                        request.targetCommunityIds()));
    }

    SocialAdAudiencePreviewResponse preview(
            String advertiserId,
            String objective,
            int maxDepth,
            int limit,
            Targeting targeting) {
        String advertiser = requireText(advertiserId, "advertiserId");
        String normalizedObjective = AdMonetizationPolicy.objective(objective);
        Targeting resolvedTargeting = Objects.requireNonNull(targeting, "targeting");
        socialAccess.ensureAdvertiserCanTargetGroups(advertiser, resolvedTargeting.targetGroupIds());
        socialAccess.ensureAdvertiserCanTargetCommunities(advertiser, resolvedTargeting.targetCommunityIds());
        return AdAudiencePlanner.preview(
                advertiser,
                normalizedObjective,
                maxDepth,
                limit,
                resolvedTargeting.targetTags(),
                resolvedTargeting.targetGroupIds(),
                resolvedTargeting.targetCommunityIds(),
                userIndex.knownUserIds(),
                blockedEitherWay,
                candidateUserId -> candidateResolver.candidate(
                        advertiser,
                        candidateUserId,
                        maxDepth,
                        resolvedTargeting.relationScopes(),
                        resolvedTargeting.targetTags(),
                        resolvedTargeting.targetGroupIds(),
                        resolvedTargeting.targetCommunityIds()));
    }

    int maxDepth(Integer maxDepth) {
        return normalizeBoundedInt(maxDepth, 2, 1, 3, "maxDepth");
    }

    int audienceLimit(Integer limit, String fieldName) {
        return normalizeBoundedInt(limit, 25, 1, maxAudienceLimit, fieldName);
    }

    Targeting targeting(
            java.util.List<String> relationScopes,
            java.util.List<String> targetTags,
            java.util.List<String> targetGroupIds,
            java.util.List<String> targetCommunityIds) {
        return new Targeting(
                AdTargetingPolicy.relationScopes(relationScopes),
                AdTargetingPolicy.targetTags(targetTags),
                AdTargetingPolicy.targetIds(targetGroupIds, "targetGroupIds"),
                AdTargetingPolicy.targetIds(targetCommunityIds, "targetCommunityIds"));
    }

    record Targeting(
            Set<String> relationScopes,
            Set<String> targetTags,
            Set<String> targetGroupIds,
            Set<String> targetCommunityIds) {
    }
}
