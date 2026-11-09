package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.util.Objects;
import java.util.function.BiFunction;
import java.util.function.Function;

/**
 * Coordinates recommendation endpoint workflows for candidate planning, pagination, and response hydration.
 */
final class SocialRecommendationCoordinator {
    private static final int DEFAULT_RECOMMENDATION_LIMIT = 100;
    private static final int DEFAULT_PREVIEW_LIMIT = 3;

    private final SocialRecommendationEndpointReadModel endpointReadModel;

    SocialRecommendationCoordinator(
            SocialGraphRepository repository,
            Function<String, String> userLabel,
            BiFunction<String, String, SocialUserProfileCardResponse> userCard,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        Function<String, String> resolvedUserLabel = Objects.requireNonNull(userLabel, "userLabel");
        BiFunction<String, String, SocialUserProfileCardResponse> resolvedUserCard =
                Objects.requireNonNull(userCard, "userCard");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        SocialRecommendationReadModel readModel = new SocialRecommendationReadModel(
                resolvedRepository,
                new SocialRecommendationPlanner(resolvedRepository),
                new SocialRecommendationPaginationPlanner(),
                resolvedUserLabel,
                resolvedUserCard,
                resolvedLimits.previewLimit());
        this.endpointReadModel = new SocialRecommendationEndpointReadModel(
                readModel,
                resolvedLimits.recommendationLimit());
    }

    SocialRecommendationsResponse recommendations(String userId, Integer limit, String cursor) {
        return endpointReadModel.recommendations(userId, limit, cursor);
    }

    static Limits defaultLimits() {
        return new Limits(DEFAULT_RECOMMENDATION_LIMIT, DEFAULT_PREVIEW_LIMIT);
    }

    /**
     * Defines endpoint and preview limits for recommendation responses.
     */
    record Limits(int recommendationLimit, int previewLimit) {
    }
}
