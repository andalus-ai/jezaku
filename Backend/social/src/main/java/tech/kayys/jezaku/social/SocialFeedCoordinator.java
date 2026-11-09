package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserContentListResponse;

import java.util.Objects;
import java.util.function.BiFunction;

/**
 * Coordinates feed endpoint workflows for global feeds, following feeds, and user content timelines.
 */
final class SocialFeedCoordinator {
    private static final int DEFAULT_FEED_LIMIT = 100;

    private final SocialFeedReadModel readModel;

    SocialFeedCoordinator(
            SocialGraphRepository repository,
            SocialContentAccessResolver contentAccessResolver,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            SocialContentRankingPolicy contentRankingPolicy,
            SocialUserStatsResolver userStatsResolver,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext,
            BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse,
            SocialContentPaginationPlanner contentPaginationPlanner,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialContentAccessResolver resolvedContentAccessResolver =
                Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        SocialEngagementSummaryResolver resolvedEngagementSummaryResolver =
                Objects.requireNonNull(engagementSummaryResolver, "engagementSummaryResolver");
        SocialContentRankingPolicy resolvedContentRankingPolicy =
                Objects.requireNonNull(contentRankingPolicy, "contentRankingPolicy");
        SocialUserStatsResolver resolvedUserStatsResolver =
                Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        BiFunction<String, String, SocialRelationshipContextResponse> resolvedRelationshipContext =
                Objects.requireNonNull(relationshipContext, "relationshipContext");
        BiFunction<SocialContentRecord, String, SocialContentResponse> resolvedContentResponse =
                Objects.requireNonNull(contentResponse, "contentResponse");
        SocialContentPaginationPlanner resolvedContentPaginationPlanner =
                Objects.requireNonNull(contentPaginationPlanner, "contentPaginationPlanner");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        this.readModel = new SocialFeedReadModel(
                resolvedRepository,
                new SocialFeedPlanner(),
                resolvedContentPaginationPlanner,
                resolvedContentAccessResolver,
                resolvedEngagementSummaryResolver,
                resolvedContentRankingPolicy,
                resolvedUserStatsResolver,
                resolvedRelationshipContext,
                resolvedContentResponse,
                resolvedLimits.feedLimit());
    }

    SocialFeedResponse feed(String viewerId, Integer limit, String cursor) {
        return readModel.feed(viewerId, limit, cursor);
    }

    SocialFeedResponse followingFeed(String userId, Integer limit, String cursor) {
        return readModel.followingFeed(userId, limit, cursor);
    }

    SocialUserContentListResponse userContent(String userId, String viewerId, Integer limit, String cursor) {
        return readModel.userContent(userId, viewerId, limit, cursor);
    }

    static Limits defaultLimits() {
        return new Limits(DEFAULT_FEED_LIMIT);
    }

    /**
     * Defines endpoint limits for feed and timeline reads.
     */
    record Limits(int feedLimit) {
    }
}
