package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialHiddenContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSavedContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;

import java.util.Objects;

/**
 * Coordinates content endpoint workflows for creation, access, tags, comments, reactions, saves, shares, and reports.
 */
final class SocialContentCoordinator {
    private static final int DEFAULT_CONTENT_ACCESS_BATCH_SIZE = 100;
    private static final int DEFAULT_SAVED_CONTENT_LIMIT = 100;
    private static final int DEFAULT_SHARE_LIST_LIMIT = 100;
    private static final int DEFAULT_HIDDEN_CONTENT_LIMIT = 100;
    private static final int DEFAULT_REPORT_LIST_LIMIT = 100;
    private static final int DEFAULT_MENTION_LIST_LIMIT = 100;
    private static final int DEFAULT_COMMENT_LIST_LIMIT = 100;
    private static final int DEFAULT_TAG_CONTENT_LIMIT = 100;
    private static final int DEFAULT_TRENDING_TAG_LIMIT = 100;

    private final SocialContentAccessReadModel contentAccessReadModel;
    private final SocialContentReadModel contentReadModel;
    private final SocialTagEndpointModel tagEndpointModel;
    private final SocialContentLifecycleEndpointWriteModel lifecycleWriteModel;
    private final SocialContentInteractionEndpointWriteModel interactionWriteModel;

    SocialContentCoordinator(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy circleMembershipPolicy,
            SocialContentAccessResolver contentAccessResolver,
            SocialActivityPublisher activityPublisher,
            SocialContentPresentationResolver contentPresentationResolver,
            SocialPresentationGateway presentationGateway,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            SocialContentRankingPolicy contentRankingPolicy,
            SocialContentPaginationPlanner contentPaginationPlanner,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialCircleMembershipPolicy resolvedCircleMembershipPolicy =
                Objects.requireNonNull(circleMembershipPolicy, "circleMembershipPolicy");
        SocialContentAccessResolver resolvedContentAccessResolver =
                Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        SocialActivityPublisher resolvedActivityPublisher =
                Objects.requireNonNull(activityPublisher, "activityPublisher");
        SocialContentPresentationResolver resolvedContentPresentationResolver =
                Objects.requireNonNull(contentPresentationResolver, "contentPresentationResolver");
        SocialPresentationGateway resolvedPresentationGateway =
                Objects.requireNonNull(presentationGateway, "presentationGateway");
        SocialEngagementSummaryResolver resolvedEngagementSummaryResolver =
                Objects.requireNonNull(engagementSummaryResolver, "engagementSummaryResolver");
        SocialContentRankingPolicy resolvedContentRankingPolicy =
                Objects.requireNonNull(contentRankingPolicy, "contentRankingPolicy");
        SocialContentPaginationPlanner resolvedContentPaginationPlanner =
                Objects.requireNonNull(contentPaginationPlanner, "contentPaginationPlanner");
        SocialChronologicalPaginationPlanner resolvedChronologicalPaginationPlanner =
                Objects.requireNonNull(chronologicalPaginationPlanner, "chronologicalPaginationPlanner");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        this.contentAccessReadModel = new SocialContentAccessReadModel(
                resolvedRepository,
                resolvedContentAccessResolver,
                resolvedLimits.contentAccessBatchSize());
        SocialContentLibraryReadModel contentLibraryReadModel = new SocialContentLibraryReadModel(
                resolvedRepository,
                resolvedContentPaginationPlanner,
                resolvedContentAccessResolver::audienceVisibleAndNotHidden,
                (content, userId) -> resolvedContentAccessResolver.audience(content, userId).canView());
        SocialContentInteractionReadModel contentInteractionReadModel = new SocialContentInteractionReadModel(
                resolvedRepository,
                resolvedChronologicalPaginationPlanner,
                resolvedActivityPublisher::mentionVisibleToUser);
        this.contentReadModel = new SocialContentReadModel(
                resolvedRepository,
                resolvedContentAccessResolver,
                contentLibraryReadModel,
                contentInteractionReadModel,
                resolvedPresentationGateway::content,
                resolvedPresentationGateway::share,
                resolvedPresentationGateway::contentReport,
                resolvedPresentationGateway::mention,
                resolvedPresentationGateway::comment,
                resolvedLimits.savedContentLimit(),
                resolvedLimits.shareListLimit(),
                resolvedLimits.hiddenContentLimit(),
                resolvedLimits.reportListLimit(),
                resolvedLimits.mentionListLimit(),
                resolvedLimits.commentListLimit());

        SocialContentLifecycleWriteModel contentLifecycleWriteModel = new SocialContentLifecycleWriteModel(
                resolvedRepository,
                resolvedCircleMembershipPolicy,
                resolvedActivityPublisher::recordActivity,
                resolvedActivityPublisher::recordMentions);
        this.lifecycleWriteModel = new SocialContentLifecycleEndpointWriteModel(
                contentLifecycleWriteModel,
                resolvedContentPresentationResolver);
        SocialContentInteractionWriteModel contentInteractionWriteModel = new SocialContentInteractionWriteModel(
                resolvedRepository,
                resolvedContentAccessResolver,
                resolvedActivityPublisher::recordActivity,
                resolvedActivityPublisher::recordMentions);
        this.interactionWriteModel = new SocialContentInteractionEndpointWriteModel(
                contentInteractionWriteModel,
                resolvedContentPresentationResolver);

        SocialTagReadModel tagReadModel = new SocialTagReadModel(
                resolvedRepository,
                resolvedContentPaginationPlanner,
                resolvedContentAccessResolver,
                resolvedEngagementSummaryResolver,
                resolvedContentRankingPolicy,
                resolvedPresentationGateway::content,
                resolvedLimits.tagContentLimit(),
                resolvedLimits.trendingTagLimit());
        this.tagEndpointModel = new SocialTagEndpointModel(
                tagReadModel,
                new SocialTagFollowWriteModel(resolvedRepository));
    }

    SocialContentResponse createContent(SocialContentCreateRequest request) {
        return lifecycleWriteModel.createContent(request);
    }

    SocialContentResponse updateContent(String contentId, SocialContentUpdateRequest request) {
        return lifecycleWriteModel.updateContent(contentId, request);
    }

    void deleteContent(String contentId, String actorUserId) {
        lifecycleWriteModel.deleteContent(contentId, actorUserId);
    }

    SocialContentResponse content(String contentId, String viewerId) {
        return contentReadModel.content(contentId, viewerId);
    }

    SocialContentAccessResponse contentAccess(SocialContentAccessRequest request) {
        return contentAccessReadModel.access(request);
    }

    SocialTagContentListResponse tagContent(String tag, String viewerId, Integer limit, String cursor) {
        return tagEndpointModel.tagContent(tag, viewerId, limit, cursor);
    }

    SocialTrendingTagListResponse trendingTags(String viewerId, Integer limit) {
        return tagEndpointModel.trendingTags(viewerId, limit);
    }

    SocialTagFollowResponse followTag(String tag, SocialTagFollowRequest request) {
        return tagEndpointModel.followTag(tag, request);
    }

    void unfollowTag(String tag, String userId) {
        tagEndpointModel.unfollowTag(tag, userId);
    }

    SocialFollowedTagListResponse followedTags(String userId, Integer limit) {
        return tagEndpointModel.followedTags(userId, limit);
    }

    SocialTopicFeedResponse topicFeed(String userId, Integer limit, String cursor) {
        return tagEndpointModel.topicFeed(userId, limit, cursor);
    }

    SocialReactionResponse likeContent(String contentId, SocialReactionRequest request) {
        return interactionWriteModel.likeContent(contentId, request);
    }

    void unlikeContent(String contentId, String userId) {
        interactionWriteModel.unlikeContent(contentId, userId);
    }

    SocialSaveResponse saveContent(String contentId, SocialSaveRequest request) {
        return interactionWriteModel.saveContent(contentId, request);
    }

    void unsaveContent(String contentId, String userId) {
        interactionWriteModel.unsaveContent(contentId, userId);
    }

    SocialSavedContentListResponse savedContent(String userId, Integer limit, String cursor) {
        return contentReadModel.savedContent(userId, limit, cursor);
    }

    SocialShareResponse shareContent(String contentId, SocialShareCreateRequest request) {
        return interactionWriteModel.shareContent(contentId, request);
    }

    SocialShareListResponse shares(String contentId, String viewerId, Integer limit, String cursor) {
        return contentReadModel.shares(contentId, viewerId, limit, cursor);
    }

    SocialContentHideResponse hideContent(String contentId, SocialContentHideRequest request) {
        return interactionWriteModel.hideContent(contentId, request);
    }

    void unhideContent(String contentId, String userId) {
        interactionWriteModel.unhideContent(contentId, userId);
    }

    SocialHiddenContentListResponse hiddenContent(String userId, Integer limit, String cursor) {
        return contentReadModel.hiddenContent(userId, limit, cursor);
    }

    SocialContentReportResponse reportContent(String contentId, SocialContentReportRequest request) {
        return interactionWriteModel.reportContent(contentId, request);
    }

    SocialContentReportListResponse contentReports(String status, Integer limit, String cursor) {
        return contentReadModel.reports(status, limit, cursor);
    }

    SocialMentionListResponse contentMentions(
            String contentId,
            String viewerId,
            Integer limit,
            String cursor) {
        return contentReadModel.contentMentions(contentId, viewerId, limit, cursor);
    }

    SocialMentionListResponse userMentions(String userId, Integer limit, String cursor) {
        return contentReadModel.userMentions(userId, limit, cursor);
    }

    SocialCommentResponse addComment(String contentId, SocialCommentCreateRequest request) {
        return interactionWriteModel.addComment(contentId, request);
    }

    SocialCommentListResponse comments(
            String contentId,
            String viewerId,
            String parentCommentId,
            Integer limit,
            String cursor) {
        return contentReadModel.comments(contentId, viewerId, parentCommentId, limit, cursor);
    }

    SocialCommentReactionResponse likeComment(
            String contentId,
            String commentId,
            SocialReactionRequest request) {
        return interactionWriteModel.likeComment(contentId, commentId, request);
    }

    void unlikeComment(String contentId, String commentId, String userId) {
        interactionWriteModel.unlikeComment(contentId, commentId, userId);
    }

    void removeComment(String contentId, String commentId, String actorUserId) {
        interactionWriteModel.removeComment(contentId, commentId, actorUserId);
    }

    static Limits defaultLimits() {
        return new Limits(
                DEFAULT_CONTENT_ACCESS_BATCH_SIZE,
                DEFAULT_SAVED_CONTENT_LIMIT,
                DEFAULT_SHARE_LIST_LIMIT,
                DEFAULT_HIDDEN_CONTENT_LIMIT,
                DEFAULT_REPORT_LIST_LIMIT,
                DEFAULT_MENTION_LIST_LIMIT,
                DEFAULT_COMMENT_LIST_LIMIT,
                DEFAULT_TAG_CONTENT_LIMIT,
                DEFAULT_TRENDING_TAG_LIMIT);
    }

    /**
     * Defines endpoint limits for content access, saved lists, interaction lists, and tag feeds.
     */
    record Limits(
            int contentAccessBatchSize,
            int savedContentLimit,
            int shareListLimit,
            int hiddenContentLimit,
            int reportListLimit,
            int mentionListLimit,
            int commentListLimit,
            int tagContentLimit,
            int trendingTagLimit) {
    }
}
