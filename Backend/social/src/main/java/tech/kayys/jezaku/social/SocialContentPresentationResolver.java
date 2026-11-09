package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.util.List;
import java.util.Objects;
import java.util.function.BiFunction;
import java.util.function.BiPredicate;

final class SocialContentPresentationResolver {
    private final SocialGraphRepository repository;
    private final SocialEngagementSummaryResolver engagementSummaryResolver;
    private final BiFunction<String, String, SocialUserProfileCardResponse> userCard;
    private final BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision;
    private final BiPredicate<String, String> contentHidden;

    SocialContentPresentationResolver(
            SocialGraphRepository repository,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            BiFunction<String, String, SocialUserProfileCardResponse> userCard,
            BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision,
            BiPredicate<String, String> contentHidden) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.engagementSummaryResolver = Objects.requireNonNull(
                engagementSummaryResolver,
                "engagementSummaryResolver");
        this.userCard = Objects.requireNonNull(userCard, "userCard");
        this.audienceDecision = Objects.requireNonNull(audienceDecision, "audienceDecision");
        this.contentHidden = Objects.requireNonNull(contentHidden, "contentHidden");
    }

    SocialContentResponse content(SocialContentRecord content, String viewerId) {
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                engagementSummaryResolver.content(content.contentId(), viewerId);
        return new SocialContentResponse(
                content.contentId(),
                content.ownerId(),
                userCard.apply(content.ownerId(), viewerId),
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
                contentHidden.test(content.contentId(), viewerId),
                tags(content.contentId()),
                audienceDecision.apply(content, viewerId));
    }

    SocialReactionResponse reaction(SocialReactionRecord reaction, String viewerId) {
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                engagementSummaryResolver.content(reaction.contentId(), viewerId);
        return new SocialReactionResponse(
                reaction.contentId(),
                reaction.userId(),
                userCard.apply(reaction.userId(), viewerId),
                reaction.reactionType(),
                reaction.createdAt(),
                engagement.likeCount());
    }

    SocialCommentResponse comment(SocialCommentRecord comment, String viewerId) {
        SocialEngagementSummaryResolver.CommentEngagementSummary engagement =
                engagementSummaryResolver.comment(comment.commentId(), viewerId);
        return new SocialCommentResponse(
                comment.commentId(),
                comment.contentId(),
                comment.authorId(),
                userCard.apply(comment.authorId(), viewerId),
                comment.text(),
                comment.parentCommentId(),
                engagement.replyCount(),
                engagement.likeCount(),
                engagement.viewerLiked(),
                comment.createdAt());
    }

    SocialCommentReactionResponse commentReaction(SocialCommentReactionRecord reaction, String viewerId) {
        SocialEngagementSummaryResolver.CommentEngagementSummary engagement =
                engagementSummaryResolver.comment(reaction.commentId(), viewerId);
        return new SocialCommentReactionResponse(
                reaction.commentId(),
                reaction.userId(),
                userCard.apply(reaction.userId(), viewerId),
                reaction.reactionType(),
                reaction.createdAt(),
                engagement.likeCount());
    }

    SocialSaveResponse save(SocialSaveRecord save, String viewerId) {
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                engagementSummaryResolver.content(save.contentId(), viewerId);
        return new SocialSaveResponse(
                save.contentId(),
                save.userId(),
                userCard.apply(save.userId(), viewerId),
                save.createdAt(),
                engagement.saveCount());
    }

    SocialShareResponse share(SocialShareRecord share, String viewerId) {
        SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                engagementSummaryResolver.content(share.contentId(), viewerId);
        return new SocialShareResponse(
                share.shareId(),
                share.contentId(),
                share.userId(),
                userCard.apply(share.userId(), viewerId),
                share.message(),
                share.createdAt(),
                engagement.shareCount());
    }

    SocialContentHideResponse contentHide(SocialContentHideRecord hide) {
        return new SocialContentHideResponse(
                hide.contentId(),
                hide.userId(),
                hide.reason(),
                hide.createdAt());
    }

    SocialContentReportResponse contentReport(SocialContentReportRecord report) {
        return new SocialContentReportResponse(
                report.reportId(),
                report.contentId(),
                report.reporterId(),
                report.reason(),
                report.detail(),
                report.status(),
                report.createdAt(),
                report.updatedAt());
    }

    SocialMentionResponse mention(SocialMentionRecord mention, String viewerId) {
        return new SocialMentionResponse(
                mention.mentionId(),
                mention.contentId(),
                mention.commentId(),
                mention.actorId(),
                userCard.apply(mention.actorId(), viewerId),
                mention.mentionedUserId(),
                userCard.apply(mention.mentionedUserId(), viewerId),
                mention.sourceType(),
                mention.createdAt());
    }

    String title(SocialContentRecord content) {
        String caption = content.caption() == null ? "" : content.caption().trim();
        if (caption.isEmpty()) {
            return content.contentId();
        }
        return caption.length() <= 80 ? caption : caption.substring(0, 77) + "...";
    }

    List<String> tags(String contentId) {
        return repository.contentTags(contentId).stream()
                .map(SocialContentTagRecord::tag)
                .distinct()
                .sorted()
                .toList();
    }
}
