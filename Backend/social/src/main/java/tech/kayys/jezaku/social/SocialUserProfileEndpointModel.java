package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

import java.util.Objects;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialUserProfileEndpointModel {
    private final SocialUserProfileWriteModel writeModel;
    private final SocialUserProfileResolver profileResolver;
    private final SocialUserProfileSummaryResolver summaryResolver;

    SocialUserProfileEndpointModel(
            SocialUserProfileWriteModel writeModel,
            SocialUserProfileResolver profileResolver,
            SocialUserProfileSummaryResolver summaryResolver) {
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.profileResolver = Objects.requireNonNull(profileResolver, "profileResolver");
        this.summaryResolver = Objects.requireNonNull(summaryResolver, "summaryResolver");
    }

    SocialUserProfileResponse updateUserProfile(String userId, SocialUserProfileUpdateRequest request) {
        return profileResolver.response(writeModel.updateProfile(userId, request));
    }

    SocialUserProfileSummaryResponse userProfile(String userId, String viewerId) {
        String user = requireText(userId, "userId");
        String viewer = requireText(viewerId, "viewerId");
        return summaryResolver.summary(user, viewer);
    }
}
