package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;

import java.time.Instant;
import java.util.Objects;
import java.util.function.BiPredicate;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class AdDeliveryReadModel {
    private final AdMonetizationReadModel monetizationReadModel;
    private final AdSocialAccess socialAccess;
    private final AdAudienceCandidateResolver audienceCandidateResolver;
    private final BiPredicate<String, String> blockedEitherWay;
    private final int maxDeliveryLimit;
    private final int maxImpressionsPerViewer;
    private final Supplier<Instant> now;

    AdDeliveryReadModel(
            AdMonetizationReadModel monetizationReadModel,
            AdSocialAccess socialAccess,
            AdAudienceCandidateResolver audienceCandidateResolver,
            BiPredicate<String, String> blockedEitherWay,
            int maxDeliveryLimit,
            int maxImpressionsPerViewer,
            Supplier<Instant> now) {
        this.monetizationReadModel = Objects.requireNonNull(monetizationReadModel, "monetizationReadModel");
        this.socialAccess = Objects.requireNonNull(socialAccess, "socialAccess");
        this.audienceCandidateResolver = Objects.requireNonNull(
                audienceCandidateResolver,
                "audienceCandidateResolver");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
        this.maxDeliveryLimit = maxDeliveryLimit;
        this.maxImpressionsPerViewer = maxImpressionsPerViewer;
        this.now = Objects.requireNonNull(now, "now");
    }

    SocialAdDeliveryResponse delivery(String viewerId, String placement, Integer limit) {
        String viewer = requireText(viewerId, "viewerId");
        String normalizedPlacement = AdMonetizationPolicy.placement(placement);
        int normalizedLimit = normalizeBoundedInt(limit, 3, 1, maxDeliveryLimit, "limit");
        Instant generatedAt = now.get();
        return AdDeliveryPlanner.response(
                viewer,
                normalizedPlacement,
                normalizedLimit,
                generatedAt,
                monetizationReadModel.campaignsForDeliveryConsideration(),
                maxImpressionsPerViewer,
                monetizationReadModel::remainingBudgetCents,
                blockedEitherWay,
                socialAccess::creativeVisibleToViewer,
                audienceCandidateResolver::campaignCandidate,
                monetizationReadModel::recentImpressionCount);
    }
}
