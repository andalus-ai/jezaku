package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;

import java.util.Objects;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialRecommendationEndpointReadModel {
    private static final int DEFAULT_LIMIT = 20;

    private final SocialRecommendationReadModel readModel;
    private final int maxLimit;

    SocialRecommendationEndpointReadModel(
            SocialRecommendationReadModel readModel,
            int maxLimit) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.maxLimit = maxLimit;
    }

    SocialRecommendationsResponse recommendations(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, DEFAULT_LIMIT, 1, maxLimit, "limit");
        return readModel.recommendations(user, normalizedLimit, cursor);
    }
}
