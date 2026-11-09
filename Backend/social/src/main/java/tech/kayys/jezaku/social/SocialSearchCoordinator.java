package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialSearchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.Objects;
import java.util.function.BiFunction;

/**
 * Coordinates search endpoint workflows for people, circles, tags, and content discovery.
 */
final class SocialSearchCoordinator {
    private static final int DEFAULT_SEARCH_LIMIT = 50;

    private final SocialSearchReadModel readModel;

    SocialSearchCoordinator(
            SocialGraphRepository repository,
            SocialUserProfileResolver profileResolver,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext,
            SocialUserStatsResolver userStatsResolver,
            SocialContentAccessResolver contentAccessResolver,
            SocialRelationshipPolicy relationshipPolicy,
            SocialContentPresentationResolver contentPresentationResolver,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            SocialContentRankingPolicy contentRankingPolicy,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialUserProfileResolver resolvedProfileResolver =
                Objects.requireNonNull(profileResolver, "profileResolver");
        BiFunction<String, String, SocialRelationshipContextResponse> resolvedRelationshipContext =
                Objects.requireNonNull(relationshipContext, "relationshipContext");
        SocialUserStatsResolver resolvedUserStatsResolver =
                Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        SocialContentAccessResolver resolvedContentAccessResolver =
                Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        SocialRelationshipPolicy resolvedRelationshipPolicy =
                Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        SocialContentPresentationResolver resolvedContentPresentationResolver =
                Objects.requireNonNull(contentPresentationResolver, "contentPresentationResolver");
        SocialEngagementSummaryResolver resolvedEngagementSummaryResolver =
                Objects.requireNonNull(engagementSummaryResolver, "engagementSummaryResolver");
        SocialContentRankingPolicy resolvedContentRankingPolicy =
                Objects.requireNonNull(contentRankingPolicy, "contentRankingPolicy");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        SocialSearchCandidateAccess candidateAccess = new SocialSearchCandidateAccess(
                resolvedProfileResolver,
                resolvedRelationshipContext,
                resolvedUserStatsResolver,
                resolvedContentAccessResolver,
                resolvedRelationshipPolicy,
                resolvedContentPresentationResolver);
        SocialSearchCandidatePlanner candidatePlanner = new SocialSearchCandidatePlanner(
                resolvedRepository,
                new SocialGraphUserIndex(resolvedRepository),
                resolvedEngagementSummaryResolver,
                resolvedContentRankingPolicy,
                new SocialSearchScoringPolicy(),
                candidateAccess);
        this.readModel = new SocialSearchReadModel(
                candidatePlanner,
                new SocialSearchPaginationPlanner(),
                resolvedLimits.searchLimit());
    }

    SocialSearchResponse search(String viewerId, String query, String types, Integer limit, String cursor) {
        return readModel.search(viewerId, query, types, limit, cursor);
    }

    static Limits defaultLimits() {
        return new Limits(DEFAULT_SEARCH_LIMIT);
    }

    /**
     * Defines endpoint limits for search result pagination.
     */
    record Limits(int searchLimit) {
    }
}
