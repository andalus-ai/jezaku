package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagResponse;

import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.BiFunction;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialTagReadModel {
    private final SocialContentGraphStore repository;
    private final SocialContentPaginationPlanner contentPaginationPlanner;
    private final SocialContentAccessResolver contentAccessResolver;
    private final SocialEngagementSummaryResolver engagementSummaryResolver;
    private final SocialContentRankingPolicy contentRankingPolicy;
    private final BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse;
    private final int maxTagContentLimit;
    private final int maxTrendingTagLimit;

    SocialTagReadModel(
            SocialContentGraphStore repository,
            SocialContentPaginationPlanner contentPaginationPlanner,
            SocialContentAccessResolver contentAccessResolver,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            SocialContentRankingPolicy contentRankingPolicy,
            BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse,
            int maxTagContentLimit,
            int maxTrendingTagLimit) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.contentPaginationPlanner = Objects.requireNonNull(contentPaginationPlanner, "contentPaginationPlanner");
        this.contentAccessResolver = Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        this.engagementSummaryResolver = Objects.requireNonNull(engagementSummaryResolver, "engagementSummaryResolver");
        this.contentRankingPolicy = Objects.requireNonNull(contentRankingPolicy, "contentRankingPolicy");
        this.contentResponse = Objects.requireNonNull(contentResponse, "contentResponse");
        this.maxTagContentLimit = maxTagContentLimit;
        this.maxTrendingTagLimit = maxTrendingTagLimit;
    }

    SocialTagContentListResponse tagContent(String tag, String viewerId, Integer limit, String cursor) {
        String normalizedTag = SocialTagPolicy.normalizeTag(tag);
        String viewer = requireText(viewerId, "viewerId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxTagContentLimit, "limit");
        List<SocialContentPaginationPlanner.ContentCandidate> candidates = repository.taggedContent(normalizedTag)
                .stream()
                .map(contentTag -> new SocialContentPaginationPlanner.ContentCandidate(
                        repository.content(contentTag.contentId()),
                        contentTag.createdAt()))
                .filter(item -> item.content() != null)
                .filter(item -> contentAccessResolver.visibleForViewer(item.content(), viewer))
                .toList();
        SocialContentPaginationPlanner.Page page = contentPaginationPlanner.timeline(
                normalizedLimit,
                cursor,
                candidates);
        return new SocialTagContentListResponse(
                normalizedTag,
                viewer,
                page.contents().size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                contentResponses(page.contents(), viewer));
    }

    SocialTrendingTagListResponse trendingTags(String viewerId, Integer limit) {
        String viewer = requireText(viewerId, "viewerId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxTrendingTagLimit, "limit");
        List<SocialTrendingTagResponse> tags = repository.tags().stream()
                .map(SocialContentTagRecord::tag)
                .distinct()
                .map(tag -> trendingTag(tag, viewer))
                .filter(tag -> tag.visibleContentCount() > 0)
                .sorted(Comparator.comparingDouble(SocialTrendingTagResponse::score).reversed()
                        .thenComparing(SocialTrendingTagResponse::tag))
                .limit(normalizedLimit)
                .toList();
        return new SocialTrendingTagListResponse(viewer, tags.size(), normalizedLimit, tags);
    }

    SocialFollowedTagListResponse followedTags(String userId, Integer limit) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, maxTrendingTagLimit, "limit");
        List<SocialTagFollowResponse> tags = repository.tagFollowsByUser(user).stream()
                .sorted(Comparator.comparing(SocialTagFollowRecord::tag))
                .limit(normalizedLimit)
                .map(this::tagFollowResponse)
                .toList();
        return new SocialFollowedTagListResponse(user, tags.size(), normalizedLimit, tags);
    }

    SocialTopicFeedResponse topicFeed(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxTagContentLimit, "limit");
        List<String> followedTags = followedTagNames(user);
        Map<String, SocialContentRecord> contentById = new HashMap<>();
        for (String tag : followedTags) {
            repository.taggedContent(tag).stream()
                    .map(contentTag -> repository.content(contentTag.contentId()))
                    .filter(content -> content != null)
                    .filter(content -> contentAccessResolver.visibleForViewer(content, user))
                    .forEach(content -> contentById.putIfAbsent(content.contentId(), content));
        }
        List<SocialContentPaginationPlanner.RankedCandidate> candidates = contentById.values().stream()
                .map(content -> new SocialContentPaginationPlanner.RankedCandidate(
                        content,
                        topicFeedScore(content, followedTags)))
                .toList();
        SocialContentPaginationPlanner.Page page = contentPaginationPlanner.ranked(
                normalizedLimit,
                cursor,
                candidates);
        return new SocialTopicFeedResponse(
                user,
                page.contents().size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                followedTags,
                contentResponses(page.contents(), user));
    }

    private SocialTrendingTagResponse trendingTag(String tag, String viewerId) {
        List<SocialContentTagRecord> tagRecords = repository.taggedContent(tag);
        List<SocialContentRecord> visibleContent = tagRecords.stream()
                .map(contentTag -> repository.content(contentTag.contentId()))
                .filter(content -> content != null)
                .filter(content -> contentAccessResolver.visibleForViewer(content, viewerId))
                .toList();
        double score = visibleContent.stream()
                .mapToDouble(content -> {
                    SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                            engagementSummaryResolver.content(content.contentId(), viewerId);
                    return contentRankingPolicy.trendingContribution(content, engagement);
                })
                .sum();
        return new SocialTrendingTagResponse(tag, tagRecords.size(), visibleContent.size(), score);
    }

    private double topicFeedScore(SocialContentRecord content, List<String> followedTags) {
        int matchedTagCount = (int) contentTags(content.contentId()).stream()
                .filter(followedTags::contains)
                .count();
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                engagementSummaryResolver.content(content.contentId(), "");
        return contentRankingPolicy.topicFeedScore(content, matchedTagCount, engagement);
    }

    private List<String> followedTagNames(String userId) {
        return repository.tagFollowsByUser(userId).stream()
                .map(SocialTagFollowRecord::tag)
                .distinct()
                .sorted()
                .toList();
    }

    private List<String> contentTags(String contentId) {
        return repository.contentTags(contentId).stream()
                .map(SocialContentTagRecord::tag)
                .distinct()
                .sorted()
                .toList();
    }

    private List<SocialContentResponse> contentResponses(List<SocialContentRecord> contents, String viewerId) {
        return contents.stream()
                .map(content -> contentResponse.apply(content, viewerId))
                .toList();
    }

    private SocialTagFollowResponse tagFollowResponse(SocialTagFollowRecord follow) {
        return new SocialTagFollowResponse(follow.userId(), follow.tag(), follow.createdAt());
    }
}
