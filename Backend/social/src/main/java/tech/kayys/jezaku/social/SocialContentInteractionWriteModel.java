package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;

import java.time.Instant;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

final class SocialContentInteractionWriteModel {
    private static final Set<String> REACTION_TYPES = Set.of("like");
    private static final Set<String> CONTENT_REPORT_REASONS = Set.of(
            "spam",
            "abuse",
            "nudity",
            "violence",
            "harassment",
            "scam",
            "other");

    private final SocialGraphRepository repository;
    private final SocialContentAccessResolver contentAccessResolver;
    private final ActivityRecorder activityRecorder;
    private final MentionRecorder mentionRecorder;
    private final SocialCommentThreadDeletionPlanner commentThreadDeletionPlanner;
    private final Supplier<Instant> now;
    private final Supplier<String> shareIds;
    private final Supplier<String> reportIds;
    private final Supplier<String> commentIds;

    SocialContentInteractionWriteModel(
            SocialGraphRepository repository,
            SocialContentAccessResolver contentAccessResolver,
            ActivityRecorder activityRecorder,
            MentionRecorder mentionRecorder) {
        this(
                repository,
                contentAccessResolver,
                activityRecorder,
                mentionRecorder,
                Instant::now,
                () -> "share_" + UUID.randomUUID(),
                () -> "report_" + UUID.randomUUID(),
                () -> "comment_" + UUID.randomUUID());
    }

    SocialContentInteractionWriteModel(
            SocialGraphRepository repository,
            SocialContentAccessResolver contentAccessResolver,
            ActivityRecorder activityRecorder,
            MentionRecorder mentionRecorder,
            Supplier<Instant> now,
            Supplier<String> shareIds,
            Supplier<String> reportIds,
            Supplier<String> commentIds) {
        this(
                repository,
                contentAccessResolver,
                activityRecorder,
                mentionRecorder,
                new SocialCommentThreadDeletionPlanner(),
                now,
                shareIds,
                reportIds,
                commentIds);
    }

    private SocialContentInteractionWriteModel(
            SocialGraphRepository repository,
            SocialContentAccessResolver contentAccessResolver,
            ActivityRecorder activityRecorder,
            MentionRecorder mentionRecorder,
            SocialCommentThreadDeletionPlanner commentThreadDeletionPlanner,
            Supplier<Instant> now,
            Supplier<String> shareIds,
            Supplier<String> reportIds,
            Supplier<String> commentIds) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.contentAccessResolver = Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        this.activityRecorder = Objects.requireNonNull(activityRecorder, "activityRecorder");
        this.mentionRecorder = Objects.requireNonNull(mentionRecorder, "mentionRecorder");
        this.commentThreadDeletionPlanner =
                Objects.requireNonNull(commentThreadDeletionPlanner, "commentThreadDeletionPlanner");
        this.now = Objects.requireNonNull(now, "now");
        this.shareIds = Objects.requireNonNull(shareIds, "shareIds");
        this.reportIds = Objects.requireNonNull(reportIds, "reportIds");
        this.commentIds = Objects.requireNonNull(commentIds, "commentIds");
    }

    SocialReactionRecord likeContent(String contentId, SocialReactionRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String user = requireText(request.userId(), "userId");
        requireContentView(content, user);
        SocialReactionRecord existing = repository.reaction(content.contentId(), user);
        SocialReactionRecord reaction = new SocialReactionRecord(
                content.contentId(),
                user,
                reactionType(request.reactionType()),
                existing == null ? now.get() : existing.createdAt());
        repository.saveReaction(reaction);
        if (existing == null) {
            activityRecorder.record(
                    "content_liked",
                    user,
                    content.ownerId(),
                    content.contentId(),
                    "",
                    reaction.reactionType(),
                    "");
        }
        return reaction;
    }

    void unlikeContent(String contentId, String userId) {
        String user = requireText(userId, "userId");
        SocialContentRecord content = requireContent(contentId);
        requireContentView(content, user);
        repository.removeReaction(content.contentId(), user);
    }

    SocialSaveRecord saveContent(String contentId, SocialSaveRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String user = requireText(request.userId(), "userId");
        requireContentView(content, user);
        SocialSaveRecord existing = repository.save(content.contentId(), user);
        SocialSaveRecord save = new SocialSaveRecord(
                content.contentId(),
                user,
                existing == null ? now.get() : existing.createdAt());
        repository.saveSave(save);
        return save;
    }

    void unsaveContent(String contentId, String userId) {
        String user = requireText(userId, "userId");
        SocialContentRecord content = requireContent(contentId);
        repository.removeSave(content.contentId(), user);
    }

    SocialShareRecord shareContent(String contentId, SocialShareCreateRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String user = requireText(request.userId(), "userId");
        requireContentView(content, user);
        SocialShareRecord share = new SocialShareRecord(
                shareIds.get(),
                content.contentId(),
                user,
                optionalTextMaxLength(request.message(), "", "message", 280),
                now.get());
        repository.saveShare(share);
        activityRecorder.record(
                "content_shared",
                user,
                content.ownerId(),
                content.contentId(),
                "",
                "",
                share.message());
        return share;
    }

    SocialContentHideRecord hideContent(String contentId, SocialContentHideRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String user = requireText(request.userId(), "userId");
        requireContentView(content, user);
        SocialContentHideRecord existing = repository.contentHide(content.contentId(), user);
        SocialContentHideRecord hide = new SocialContentHideRecord(
                content.contentId(),
                user,
                optionalTextMaxLength(request.reason(), "", "reason", 120),
                existing == null ? now.get() : existing.createdAt());
        repository.saveContentHide(hide);
        return hide;
    }

    void unhideContent(String contentId, String userId) {
        String user = requireText(userId, "userId");
        SocialContentRecord content = requireContent(contentId);
        repository.removeContentHide(content.contentId(), user);
    }

    SocialContentReportRecord reportContent(String contentId, SocialContentReportRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String reporter = requireText(request.reporterId(), "reporterId");
        requireContentView(content, reporter);
        SocialContentReportRecord existing = openReportBy(content.contentId(), reporter);
        if (existing != null) {
            return existing;
        }
        Instant createdAt = now.get();
        SocialContentReportRecord report = new SocialContentReportRecord(
                reportIds.get(),
                content.contentId(),
                reporter,
                contentReportReason(request.reason()),
                optionalTextMaxLength(request.detail(), "", "detail", 500),
                "open",
                createdAt,
                createdAt);
        repository.saveContentReport(report);
        return report;
    }

    SocialCommentRecord addComment(String contentId, SocialCommentCreateRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        String author = requireText(request.authorId(), "authorId");
        requireContentView(content, author);
        String parentCommentId = optionalTrim(request.parentCommentId(), "");
        SocialCommentRecord parentComment = parentCommentId.isEmpty()
                ? null
                : requireCommentOnContent(content, parentCommentId);
        SocialCommentRecord comment = new SocialCommentRecord(
                commentIds.get(),
                content.contentId(),
                author,
                requireTextMaxLength(request.text(), "text", 500),
                parentCommentId,
                now.get());
        repository.saveComment(comment);
        activityRecorder.record(
                "content_commented",
                author,
                content.ownerId(),
                content.contentId(),
                comment.commentId(),
                "",
                comment.text());
        if (parentComment != null
                && !parentComment.authorId().equals(author)
                && !parentComment.authorId().equals(content.ownerId())) {
            activityRecorder.record(
                    "comment_replied",
                    author,
                    parentComment.authorId(),
                    content.contentId(),
                    comment.commentId(),
                    "",
                    comment.text());
        }
        mentionRecorder.record(content, comment.commentId(), author, comment.text(), "comment");
        return comment;
    }

    SocialCommentReactionRecord likeComment(String contentId, String commentId, SocialReactionRequest request) {
        requireBody(request);
        SocialContentRecord content = requireContent(contentId);
        SocialCommentRecord comment = requireCommentOnContent(content, commentId);
        String user = requireText(request.userId(), "userId");
        requireContentView(content, user);
        SocialCommentReactionRecord existing = repository.commentReaction(comment.commentId(), user);
        SocialCommentReactionRecord reaction = new SocialCommentReactionRecord(
                comment.commentId(),
                user,
                reactionType(request.reactionType()),
                existing == null ? now.get() : existing.createdAt());
        repository.saveCommentReaction(reaction);
        if (existing == null) {
            activityRecorder.record(
                    "comment_liked",
                    user,
                    comment.authorId(),
                    content.contentId(),
                    comment.commentId(),
                    reaction.reactionType(),
                    "");
        }
        return reaction;
    }

    void unlikeComment(String contentId, String commentId, String userId) {
        SocialContentRecord content = requireContent(contentId);
        SocialCommentRecord comment = requireCommentOnContent(content, commentId);
        String user = requireText(userId, "userId");
        requireContentView(content, user);
        repository.removeCommentReaction(comment.commentId(), user);
    }

    void removeComment(String contentId, String commentId, String actorUserId) {
        String actor = requireText(actorUserId, "actorUserId");
        SocialContentRecord content = requireContent(contentId);
        SocialCommentRecord comment = requireComment(commentId);
        if (!comment.contentId().equals(content.contentId())) {
            throw new NotFoundException("Comment not found on content: " + commentId);
        }
        if (!actor.equals(comment.authorId()) && !actor.equals(content.ownerId())) {
            throw new ForbiddenException("Only the comment author or content owner can delete this comment");
        }
        for (String removedCommentId : commentThreadDeletionPlanner.deletionOrder(
                repository.comments(content.contentId()),
                comment.commentId())) {
            repository.removeMentionsForComment(removedCommentId);
            repository.commentReactions(removedCommentId).stream()
                    .map(SocialCommentReactionRecord::userId)
                    .toList()
                    .forEach(userId -> repository.removeCommentReaction(removedCommentId, userId));
            repository.removeComment(removedCommentId);
        }
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

    private void requireContentView(SocialContentRecord content, String viewerId) {
        contentAccessResolver.requireAudienceView(content, viewerId);
    }

    private SocialContentReportRecord openReportBy(String contentId, String reporterId) {
        return repository.contentReports().stream()
                .filter(report -> report.contentId().equals(contentId))
                .filter(report -> report.reporterId().equals(reporterId))
                .filter(report -> "open".equals(report.status()))
                .findFirst()
                .orElse(null);
    }

    private String reactionType(String reactionType) {
        return optionalChoice(reactionType, "like", REACTION_TYPES,
                "reactionType", "reactionType must be like");
    }

    private String contentReportReason(String reason) {
        return optionalChoice(reason, "other", CONTENT_REPORT_REASONS,
                "reason", "reason must be spam, abuse, nudity, violence, harassment, scam, or other");
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }

    @FunctionalInterface
    interface ActivityRecorder {
        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String reactionType,
                String message);
    }

    @FunctionalInterface
    interface MentionRecorder {
        void record(
                SocialContentRecord content,
                String commentId,
                String actorId,
                String text,
                String sourceType);
    }
}
