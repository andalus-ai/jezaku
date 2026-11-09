package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.List;
import java.util.Objects;
import java.util.function.BiFunction;

final class SocialSearchCandidateAccess implements SocialSearchCandidatePlanner.Access {
    private final SocialUserProfileResolver profileResolver;
    private final BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext;
    private final SocialUserStatsResolver userStatsResolver;
    private final SocialContentAccessResolver contentAccessResolver;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialContentPresentationResolver contentPresentationResolver;

    SocialSearchCandidateAccess(
            SocialUserProfileResolver profileResolver,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext,
            SocialUserStatsResolver userStatsResolver,
            SocialContentAccessResolver contentAccessResolver,
            SocialRelationshipPolicy relationshipPolicy,
            SocialContentPresentationResolver contentPresentationResolver) {
        this.profileResolver = Objects.requireNonNull(profileResolver, "profileResolver");
        this.relationshipContext = Objects.requireNonNull(relationshipContext, "relationshipContext");
        this.userStatsResolver = Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        this.contentAccessResolver = Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        this.contentPresentationResolver = Objects.requireNonNull(
                contentPresentationResolver,
                "contentPresentationResolver");
    }

    @Override
    public SocialUserProfileRecord profileFor(String userId) {
        return profileResolver.profileFor(userId);
    }

    @Override
    public boolean profileVisibleTo(String viewerId, String userId, SocialUserProfileRecord profile) {
        return profileResolver.visibleTo(viewerId, userId, profile);
    }

    @Override
    public SocialRelationshipContextResponse relationshipContext(String viewerId, String userId) {
        return relationshipContext.apply(viewerId, userId);
    }

    @Override
    public int visibleContentCount(String viewerId, String ownerId) {
        return userStatsResolver.visibleContentCount(viewerId, ownerId);
    }

    @Override
    public int visibleFollowerCount(String userId) {
        return userStatsResolver.visibleFollowerCount(userId);
    }

    @Override
    public int authoredContentCount(String ownerId) {
        return userStatsResolver.authoredContentCount(ownerId);
    }

    @Override
    public boolean mutedTarget(String userId, String targetType, String targetId) {
        return contentAccessResolver.mutedTarget(userId, targetType, targetId);
    }

    @Override
    public boolean blockedEitherWay(String firstUserId, String secondUserId) {
        return relationshipPolicy.blockedEitherWay(firstUserId, secondUserId);
    }

    @Override
    public SocialAudienceDecisionResponse contentAudienceDecision(SocialContentRecord content, String viewerId) {
        return contentAccessResolver.audience(content, viewerId);
    }

    @Override
    public boolean contentHidden(String contentId, String userId) {
        return contentAccessResolver.hidden(contentId, userId);
    }

    @Override
    public boolean contentMutedForViewer(SocialContentRecord content, String viewerId) {
        return contentAccessResolver.mutedForViewer(content, viewerId);
    }

    @Override
    public List<String> contentTags(String contentId) {
        return contentPresentationResolver.tags(contentId);
    }

    @Override
    public String userLabel(String userId) {
        return profileResolver.userLabel(userId);
    }

    @Override
    public String contentTitle(SocialContentRecord content) {
        return contentPresentationResolver.title(content);
    }
}
