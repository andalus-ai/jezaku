package tech.kayys.jezaku.social;

import java.util.Objects;

/**
 * Assembles shared presentation, engagement, ranking, and pagination collaborators for content surfaces.
 */
final class SocialContentSurfaceSupport {
    private final SocialEngagementSummaryResolver engagementSummaryResolver;
    private final SocialContentPresentationResolver contentPresentationResolver;
    private final SocialPresentationGateway presentationGateway;
    private final SocialContentRankingPolicy contentRankingPolicy;
    private final SocialContentPaginationPlanner contentPaginationPlanner;

    SocialContentSurfaceSupport(
            SocialGraphRepository repository,
            SocialUserProfileResolver profileResolver,
            SocialContentAccessResolver contentAccessResolver) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialUserProfileResolver resolvedProfileResolver =
                Objects.requireNonNull(profileResolver, "profileResolver");
        SocialContentAccessResolver resolvedContentAccessResolver =
                Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");

        this.contentPaginationPlanner = new SocialContentPaginationPlanner();
        this.engagementSummaryResolver = new SocialEngagementSummaryResolver(resolvedRepository);
        this.contentPresentationResolver = new SocialContentPresentationResolver(
                resolvedRepository,
                engagementSummaryResolver,
                resolvedProfileResolver::card,
                resolvedContentAccessResolver::audience,
                resolvedContentAccessResolver::hidden);
        this.presentationGateway = new SocialPresentationGateway(
                resolvedProfileResolver,
                contentPresentationResolver);
        this.contentRankingPolicy = new SocialContentRankingPolicy();
    }

    SocialEngagementSummaryResolver engagementSummaryResolver() {
        return engagementSummaryResolver;
    }

    SocialContentPresentationResolver contentPresentationResolver() {
        return contentPresentationResolver;
    }

    SocialPresentationGateway presentationGateway() {
        return presentationGateway;
    }

    SocialContentRankingPolicy contentRankingPolicy() {
        return contentRankingPolicy;
    }

    SocialContentPaginationPlanner contentPaginationPlanner() {
        return contentPaginationPlanner;
    }
}
