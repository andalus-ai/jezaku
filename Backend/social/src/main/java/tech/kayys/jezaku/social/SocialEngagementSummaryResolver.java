package tech.kayys.jezaku.social;

import java.util.Objects;

final class SocialEngagementSummaryResolver {
    private final SocialContentGraphStore repository;

    SocialEngagementSummaryResolver(SocialContentGraphStore repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    ContentEngagementSummary content(String contentId, String viewerId) {
        String normalizedViewerId = viewerId == null ? "" : viewerId;
        return new ContentEngagementSummary(
                contentLikeCount(contentId),
                repository.comments(contentId).size(),
                repository.saves(contentId).size(),
                repository.shares(contentId).size(),
                !normalizedViewerId.isBlank() && repository.reaction(contentId, normalizedViewerId) != null,
                !normalizedViewerId.isBlank() && repository.save(contentId, normalizedViewerId) != null);
    }

    CommentEngagementSummary comment(String commentId, String viewerId) {
        String normalizedViewerId = viewerId == null ? "" : viewerId;
        SocialCommentRecord comment = repository.comment(commentId);
        int replyCount = comment == null
                ? 0
                : (int) repository.comments(comment.contentId()).stream()
                        .filter(reply -> reply.parentCommentId().equals(commentId))
                        .count();
        return new CommentEngagementSummary(
                replyCount,
                commentLikeCount(commentId),
                !normalizedViewerId.isBlank() && repository.commentReaction(commentId, normalizedViewerId) != null);
    }

    private int contentLikeCount(String contentId) {
        return (int) repository.reactions(contentId).stream()
                .filter(reaction -> "like".equals(reaction.reactionType()))
                .count();
    }

    private int commentLikeCount(String commentId) {
        return (int) repository.commentReactions(commentId).stream()
                .filter(reaction -> "like".equals(reaction.reactionType()))
                .count();
    }

    record ContentEngagementSummary(
            int likeCount,
            int commentCount,
            int saveCount,
            int shareCount,
            boolean viewerLiked,
            boolean viewerSaved) {
    }

    record CommentEngagementSummary(int replyCount, int likeCount, boolean viewerLiked) {
    }
}
