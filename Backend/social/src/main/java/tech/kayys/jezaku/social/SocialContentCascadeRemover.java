package tech.kayys.jezaku.social;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

/**
 * Removes content and every graph record that is owned by or attached to that content.
 */
final class SocialContentCascadeRemover {
    private final SocialGraphRepository repository;
    private final SocialCommentThreadDeletionPlanner commentThreadDeletionPlanner;

    SocialContentCascadeRemover(SocialGraphRepository repository) {
        this(repository, new SocialCommentThreadDeletionPlanner());
    }

    SocialContentCascadeRemover(
            SocialGraphRepository repository,
            SocialCommentThreadDeletionPlanner commentThreadDeletionPlanner) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.commentThreadDeletionPlanner =
                Objects.requireNonNull(commentThreadDeletionPlanner, "commentThreadDeletionPlanner");
    }

    void remove(String contentId) {
        repository.reactions(contentId).stream()
                .map(SocialReactionRecord::userId)
                .toList()
                .forEach(userId -> repository.removeReaction(contentId, userId));
        repository.saves(contentId).stream()
                .map(SocialSaveRecord::userId)
                .toList()
                .forEach(userId -> repository.removeSave(contentId, userId));
        repository.shares(contentId).stream()
                .map(SocialShareRecord::shareId)
                .toList()
                .forEach(repository::removeShare);
        repository.contentHides(contentId).stream()
                .map(SocialContentHideRecord::userId)
                .toList()
                .forEach(userId -> repository.removeContentHide(contentId, userId));
        removeComments(contentId);
        repository.removeContentReports(contentId);
        repository.removeCircleContentModerations(contentId);
        repository.removeContentTags(contentId);
        repository.removeMentionsForContent(contentId);
        repository.removeActivitiesForContent(contentId);
        repository.removeContent(contentId);
    }

    private void removeComments(String contentId) {
        List<SocialCommentRecord> comments = repository.comments(contentId);
        Set<String> removedCommentIds = new HashSet<>();
        comments.stream()
                .filter(comment -> comment.parentCommentId().isBlank())
                .map(SocialCommentRecord::commentId)
                .map(rootCommentId -> commentThreadDeletionPlanner.deletionOrder(comments, rootCommentId))
                .flatMap(List::stream)
                .forEach(commentId -> removeCommentOnce(commentId, removedCommentIds));
        comments.stream()
                .map(SocialCommentRecord::commentId)
                .forEach(commentId -> removeCommentOnce(commentId, removedCommentIds));
    }

    private void removeCommentOnce(String commentId, Set<String> removedCommentIds) {
        if (!removedCommentIds.add(commentId)) {
            return;
        }
        repository.commentReactions(commentId).stream()
                .map(SocialCommentReactionRecord::userId)
                .toList()
                .forEach(userId -> repository.removeCommentReaction(commentId, userId));
        repository.removeComment(commentId);
    }
}
