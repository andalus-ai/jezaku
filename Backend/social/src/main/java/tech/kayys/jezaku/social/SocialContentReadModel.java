package tech.kayys.jezaku.social;

import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialHiddenContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSavedContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.function.BiFunction;
import java.util.function.Function;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialContentReadModel {
    private static final Set<String> CONTENT_REPORT_STATUSES = Set.of("open", "reviewed", "dismissed", "actioned");

    private final SocialContentGraphStore repository;
    private final SocialContentAccessResolver contentAccessResolver;
    private final SocialContentLibraryReadModel contentLibraryReadModel;
    private final SocialContentInteractionReadModel contentInteractionReadModel;
    private final BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse;
    private final BiFunction<SocialShareRecord, String, SocialShareResponse> shareResponse;
    private final Function<SocialContentReportRecord, SocialContentReportResponse> reportResponse;
    private final BiFunction<SocialMentionRecord, String, SocialMentionResponse> mentionResponse;
    private final BiFunction<SocialCommentRecord, String, SocialCommentResponse> commentResponse;
    private final int maxSavedContentLimit;
    private final int maxShareListLimit;
    private final int maxHiddenContentLimit;
    private final int maxReportListLimit;
    private final int maxMentionListLimit;
    private final int maxCommentListLimit;

    SocialContentReadModel(
            SocialContentGraphStore repository,
            SocialContentAccessResolver contentAccessResolver,
            SocialContentLibraryReadModel contentLibraryReadModel,
            SocialContentInteractionReadModel contentInteractionReadModel,
            BiFunction<SocialContentRecord, String, SocialContentResponse> contentResponse,
            BiFunction<SocialShareRecord, String, SocialShareResponse> shareResponse,
            Function<SocialContentReportRecord, SocialContentReportResponse> reportResponse,
            BiFunction<SocialMentionRecord, String, SocialMentionResponse> mentionResponse,
            BiFunction<SocialCommentRecord, String, SocialCommentResponse> commentResponse,
            int maxSavedContentLimit,
            int maxShareListLimit,
            int maxHiddenContentLimit,
            int maxReportListLimit,
            int maxMentionListLimit,
            int maxCommentListLimit) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.contentAccessResolver = Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        this.contentLibraryReadModel = Objects.requireNonNull(contentLibraryReadModel, "contentLibraryReadModel");
        this.contentInteractionReadModel =
                Objects.requireNonNull(contentInteractionReadModel, "contentInteractionReadModel");
        this.contentResponse = Objects.requireNonNull(contentResponse, "contentResponse");
        this.shareResponse = Objects.requireNonNull(shareResponse, "shareResponse");
        this.reportResponse = Objects.requireNonNull(reportResponse, "reportResponse");
        this.mentionResponse = Objects.requireNonNull(mentionResponse, "mentionResponse");
        this.commentResponse = Objects.requireNonNull(commentResponse, "commentResponse");
        this.maxSavedContentLimit = maxSavedContentLimit;
        this.maxShareListLimit = maxShareListLimit;
        this.maxHiddenContentLimit = maxHiddenContentLimit;
        this.maxReportListLimit = maxReportListLimit;
        this.maxMentionListLimit = maxMentionListLimit;
        this.maxCommentListLimit = maxCommentListLimit;
    }

    SocialContentResponse content(String contentId, String viewerId) {
        String viewer = requireText(viewerId, "viewerId");
        SocialContentRecord content = requireContent(contentId);
        requireContentView(content, viewer);
        return contentResponse.apply(content, viewer);
    }

    SocialSavedContentListResponse savedContent(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxSavedContentLimit, "limit");
        SocialContentLibraryReadModel.ContentLibraryPage page =
                contentLibraryReadModel.savedContent(user, normalizedLimit, cursor);
        List<SocialContentResponse> items = page.contents().stream()
                .map(content -> contentResponse.apply(content, user))
                .toList();
        return new SocialSavedContentListResponse(
                user,
                items.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                items);
    }

    SocialShareListResponse shares(String contentId, String viewerId, Integer limit, String cursor) {
        String viewer = requireText(viewerId, "viewerId");
        SocialContentRecord content = requireContent(contentId);
        requireContentView(content, viewer);
        int normalizedLimit = normalizeBoundedInt(limit, 25, 1, maxShareListLimit, "limit");
        SocialContentInteractionReadModel.InteractionPage<SocialShareRecord> page =
                contentInteractionReadModel.shares(content.contentId(), normalizedLimit, cursor);
        List<SocialShareResponse> shares = page.items().stream()
                .map(share -> shareResponse.apply(share, viewer))
                .toList();
        return new SocialShareListResponse(
                content.contentId(),
                shares.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                shares);
    }

    SocialHiddenContentListResponse hiddenContent(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 20, 1, maxHiddenContentLimit, "limit");
        SocialContentLibraryReadModel.ContentLibraryPage page =
                contentLibraryReadModel.hiddenContent(user, normalizedLimit, cursor);
        List<SocialContentResponse> items = page.contents().stream()
                .map(content -> contentResponse.apply(content, user))
                .toList();
        return new SocialHiddenContentListResponse(
                user,
                items.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                items);
    }

    SocialContentReportListResponse reports(String status, Integer limit, String cursor) {
        String normalizedStatus = contentReportStatusFilter(status);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, maxReportListLimit, "limit");
        SocialContentInteractionReadModel.InteractionPage<SocialContentReportRecord> page =
                contentInteractionReadModel.reports(normalizedStatus, normalizedLimit, cursor);
        List<SocialContentReportResponse> reports = page.items().stream()
                .map(reportResponse)
                .toList();
        return new SocialContentReportListResponse(
                normalizedStatus,
                reports.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                reports);
    }

    SocialMentionListResponse contentMentions(
            String contentId,
            String viewerId,
            Integer limit,
            String cursor) {
        String viewer = requireText(viewerId, "viewerId");
        SocialContentRecord content = requireContent(contentId);
        requireContentView(content, viewer);
        int normalizedLimit = normalizeBoundedInt(limit, 25, 1, maxMentionListLimit, "limit");
        SocialContentInteractionReadModel.InteractionPage<SocialMentionRecord> page =
                contentInteractionReadModel.contentMentions(content.contentId(), normalizedLimit, cursor);
        List<SocialMentionResponse> mentions = page.items().stream()
                .map(mention -> mentionResponse.apply(mention, viewer))
                .toList();
        return new SocialMentionListResponse(
                content.contentId(),
                "",
                mentions.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                mentions);
    }

    SocialMentionListResponse userMentions(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, maxMentionListLimit, "limit");
        SocialContentInteractionReadModel.InteractionPage<SocialMentionRecord> page =
                contentInteractionReadModel.userMentions(user, normalizedLimit, cursor);
        List<SocialMentionResponse> mentions = page.items().stream()
                .map(mention -> mentionResponse.apply(mention, user))
                .toList();
        return new SocialMentionListResponse(
                "",
                user,
                mentions.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                mentions);
    }

    SocialCommentListResponse comments(
            String contentId,
            String viewerId,
            String parentCommentId,
            Integer limit,
            String cursor) {
        String viewer = requireText(viewerId, "viewerId");
        SocialContentRecord content = requireContent(contentId);
        requireContentView(content, viewer);
        String normalizedParentCommentId = optionalTrim(parentCommentId, "");
        if (!normalizedParentCommentId.isEmpty()) {
            requireCommentOnContent(content, normalizedParentCommentId);
        }
        int normalizedLimit = normalizeBoundedInt(limit, 25, 1, maxCommentListLimit, "limit");
        SocialContentInteractionReadModel.InteractionPage<SocialCommentRecord> page =
                contentInteractionReadModel.comments(
                        content.contentId(),
                        normalizedParentCommentId,
                        normalizedLimit,
                        cursor);
        List<SocialCommentResponse> comments = page.items().stream()
                .map(comment -> commentResponse.apply(comment, viewer))
                .toList();
        return new SocialCommentListResponse(
                content.contentId(),
                normalizedParentCommentId,
                comments.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                comments);
    }

    private void requireContentView(SocialContentRecord content, String viewerId) {
        contentAccessResolver.requireAudienceView(content, viewerId);
    }

    private SocialContentRecord requireContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        SocialContentRecord content = repository.content(normalizedContentId);
        if (content == null) {
            throw new NotFoundException("Content not found: " + normalizedContentId);
        }
        return content;
    }

    private SocialCommentRecord requireComment(String commentId) {
        String normalizedCommentId = requireText(commentId, "commentId");
        SocialCommentRecord comment = repository.comment(normalizedCommentId);
        if (comment == null) {
            throw new NotFoundException("Comment not found: " + normalizedCommentId);
        }
        return comment;
    }

    private SocialCommentRecord requireCommentOnContent(SocialContentRecord content, String commentId) {
        SocialCommentRecord comment = requireComment(commentId);
        if (!comment.contentId().equals(content.contentId())) {
            throw new NotFoundException("Comment not found on content: " + commentId);
        }
        return comment;
    }

    private String contentReportStatusFilter(String status) {
        Set<String> statuses = new HashSet<>(CONTENT_REPORT_STATUSES);
        statuses.add("all");
        return optionalChoice(status, "open", statuses,
                "status", "status must be open, reviewed, dismissed, actioned, or all");
    }
}
