package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.util.Objects;

final class SocialPresentationGateway {
    private final SocialUserProfileResolver profileResolver;
    private final SocialContentPresentationResolver contentPresentationResolver;

    SocialPresentationGateway(
            SocialUserProfileResolver profileResolver,
            SocialContentPresentationResolver contentPresentationResolver) {
        this.profileResolver = Objects.requireNonNull(profileResolver, "profileResolver");
        this.contentPresentationResolver = Objects.requireNonNull(
                contentPresentationResolver,
                "contentPresentationResolver");
    }

    String userLabel(String userId) {
        return profileResolver.userLabel(userId);
    }

    SocialUserProfileCardResponse userProfileCard(String userId, String viewerId) {
        return profileResolver.card(userId, viewerId);
    }

    SocialContentResponse content(SocialContentRecord content, String viewerId) {
        return contentPresentationResolver.content(content, viewerId);
    }

    SocialCommentResponse comment(SocialCommentRecord comment, String viewerId) {
        return contentPresentationResolver.comment(comment, viewerId);
    }

    SocialShareResponse share(SocialShareRecord share, String viewerId) {
        return contentPresentationResolver.share(share, viewerId);
    }

    SocialContentReportResponse contentReport(SocialContentReportRecord report) {
        return contentPresentationResolver.contentReport(report);
    }

    SocialMentionResponse mention(SocialMentionRecord mention, String viewerId) {
        return contentPresentationResolver.mention(mention, viewerId);
    }
}
