package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedItem;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserContentListResponse;

import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.function.BiFunction;
import java.util.stream.Collectors;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialFeedReadModel {
    private final SocialGraphRepository repository;
    private final SocialFeedPlanner feedPlanner;
    private final SocialContentPaginationPlanner contentPaginationPlanner;
    private final SocialContentAccessResolver contentAccessResolver;
    private final SocialEngagementSummaryResolver engagementSummaryResolver;
    private final SocialContentRankingPolicy contentRankingPolicy;
    private final SocialUserStatsResolver userStatsResolver;
    private final BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext;
    private final BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse;
    private final int maxFeedLimit;

    SocialFeedReadModel(
            SocialGraphRepository repository,
            SocialFeedPlanner feedPlanner,
            SocialContentPaginationPlanner contentPaginationPlanner,
            SocialContentAccessResolver contentAccessResolver,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            SocialContentRankingPolicy contentRankingPolicy,
            SocialUserStatsResolver userStatsResolver,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext,
            BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse,
            int maxFeedLimit) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.feedPlanner = Objects.requireNonNull(feedPlanner, "feedPlanner");
        this.contentPaginationPlanner = Objects.requireNonNull(contentPaginationPlanner, "contentPaginationPlanner");
        this.contentAccessResolver = Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        this.engagementSummaryResolver = Objects.requireNonNull(engagementSummaryResolver, "engagementSummaryResolver");
        this.contentRankingPolicy = Objects.requireNonNull(contentRankingPolicy, "contentRankingPolicy");
        this.userStatsResolver = Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        this.relationshipContext = Objects.requireNonNull(relationshipContext, "relationshipContext");
        this.contentResponse = Objects.requireNonNull(contentResponse, "contentResponse");
        this.maxFeedLimit = maxFeedLimit;
    }

    SocialFeedResponse feed(String viewerId, Integer limit, String cursor) {
        String viewer = requireText(viewerId, "viewerId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxFeedLimit, "limit");
        List<SocialFeedPlanner.Candidate> candidates = repository.contents().stream()
                .map(content -> feedCandidate(content, viewer))
                .toList();
        return feedPlanner.page(viewer, normalizedLimit, cursor, candidates);
    }

    SocialFeedResponse followingFeed(String userId, Integer limit, String cursor) {
        String viewer = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxFeedLimit, "limit");
        Set<String> followedUserIds = repository.following(viewer).stream()
                .map(SocialUserFollowRecord::followedUserId)
                .collect(Collectors.toSet());
        List<SocialFeedPlanner.Candidate> candidates = repository.contents().stream()
                .filter(content -> followedUserIds.contains(content.ownerId()))
                .map(content -> feedCandidate(content, viewer))
                .toList();
        return feedPlanner.page(viewer, normalizedLimit, cursor, candidates);
    }

    SocialUserContentListResponse userContent(
            String userId,
            String viewerId,
            Integer limit,
            String cursor) {
        String owner = requireText(userId, "userId");
        String viewer = requireText(viewerId, "viewerId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxFeedLimit, "limit");
        List<SocialContentPaginationPlanner.ContentCandidate> candidates =
                userStatsResolver.visibleContentForOwner(owner, viewer).stream()
                        .map(content -> new SocialContentPaginationPlanner.ContentCandidate(
                                content,
                                content.createdAt()))
                        .toList();
        SocialContentPaginationPlanner.Page page = contentPaginationPlanner.timeline(
                normalizedLimit,
                cursor,
                candidates);
        List<SocialContentResponse> items = page.contents().stream()
                .map(content -> contentResponse.apply(content, viewer))
                .toList();
        return new SocialUserContentListResponse(
                owner,
                viewer,
                items.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                items);
    }

    private SocialFeedPlanner.Candidate feedCandidate(SocialContentRecord content, String viewerId) {
        SocialContentAccessResolver.ContentVisibility visibility = contentAccessResolver.visibility(content, viewerId);
        if (!visibility.visible()) {
            return new SocialFeedPlanner.Candidate(null);
        }
        SocialAudienceDecisionResponse audience = visibility.audience();
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                engagementSummaryResolver.content(content.contentId(), viewerId);
        SocialRelationshipContextResponse context = relationshipContext.apply(viewerId, content.ownerId());
        return new SocialFeedPlanner.Candidate(new SocialFeedItem(
                content.contentId(),
                content.ownerId(),
                content.contentType(),
                content.scope(),
                content.targetId(),
                content.caption(),
                content.createdAt(),
                engagement.likeCount(),
                engagement.commentCount(),
                engagement.saveCount(),
                engagement.shareCount(),
                engagement.viewerLiked(),
                engagement.viewerSaved(),
                context.relation(),
                audience.reason(),
                contentRankingPolicy.feedScore(content, context, engagement),
                audience));
    }
}
