package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

import java.util.Objects;
import java.util.function.BiFunction;

/**
 * Coordinates profile endpoint workflows for profile updates and viewer-aware profile summaries.
 */
final class SocialProfileCoordinator {
    private final SocialUserProfileEndpointModel endpointModel;

    SocialProfileCoordinator(
            SocialGraphRepository repository,
            SocialUserProfileResolver profileResolver,
            SocialUserStatsResolver userStatsResolver,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialUserProfileResolver resolvedProfileResolver =
                Objects.requireNonNull(profileResolver, "profileResolver");
        SocialUserStatsResolver resolvedUserStatsResolver =
                Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        BiFunction<String, String, SocialRelationshipContextResponse> resolvedRelationshipContext =
                Objects.requireNonNull(relationshipContext, "relationshipContext");

        SocialUserProfileWriteModel writeModel = new SocialUserProfileWriteModel(
                resolvedRepository,
                resolvedProfileResolver);
        SocialUserProfileSummaryResolver summaryResolver = new SocialUserProfileSummaryResolver(
                resolvedRepository,
                resolvedProfileResolver,
                resolvedUserStatsResolver,
                resolvedRelationshipContext);
        this.endpointModel = new SocialUserProfileEndpointModel(
                writeModel,
                resolvedProfileResolver,
                summaryResolver);
    }

    SocialUserProfileResponse updateUserProfile(String userId, SocialUserProfileUpdateRequest request) {
        return endpointModel.updateUserProfile(userId, request);
    }

    SocialUserProfileSummaryResponse userProfile(String userId, String viewerId) {
        return endpointModel.userProfile(userId, viewerId);
    }
}
