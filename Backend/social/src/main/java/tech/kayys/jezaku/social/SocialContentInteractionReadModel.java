package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

final class SocialContentInteractionReadModel {
    private final SocialContentGraphStore repository;
    private final SocialChronologicalPaginationPlanner chronologicalPaginationPlanner;
    private final BiPredicate<SocialMentionRecord, String> mentionVisibleToUser;

    SocialContentInteractionReadModel(
            SocialContentGraphStore repository,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            BiPredicate<SocialMentionRecord, String> mentionVisibleToUser) {
        this.repository = repository;
        this.chronologicalPaginationPlanner = chronologicalPaginationPlanner;
        this.mentionVisibleToUser = mentionVisibleToUser;
    }

    InteractionPage<SocialShareRecord> shares(String contentId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialShareRecord>> candidates =
                repository.shares(contentId).stream()
                        .map(share -> candidate(share, share.createdAt(), share.shareId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    InteractionPage<SocialContentReportRecord> reports(String status, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialContentReportRecord>> candidates =
                repository.contentReports().stream()
                        .filter(report -> "all".equals(status) || report.status().equals(status))
                        .map(report -> candidate(report, report.createdAt(), report.reportId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    InteractionPage<SocialMentionRecord> contentMentions(String contentId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialMentionRecord>> candidates =
                repository.mentions(contentId).stream()
                        .map(mention -> candidate(mention, mention.createdAt(), mention.mentionId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    InteractionPage<SocialMentionRecord> userMentions(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialMentionRecord>> candidates =
                repository.mentionsForUser(userId).stream()
                        .filter(mention -> mentionVisibleToUser.test(mention, userId))
                        .map(mention -> candidate(mention, mention.createdAt(), mention.mentionId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    InteractionPage<SocialCommentRecord> comments(
            String contentId,
            String parentCommentId,
            int limit,
            String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialCommentRecord>> candidates =
                repository.comments(contentId).stream()
                        .filter(comment -> comment.parentCommentId().equals(parentCommentId))
                        .map(comment -> candidate(comment, comment.createdAt(), comment.commentId()))
                        .toList();
        SocialChronologicalPaginationPlanner.Page<SocialCommentRecord> page =
                chronologicalPaginationPlanner.ascending(limit, cursor, candidates);
        return new InteractionPage<>(page.items(), page.hasMore(), page.nextCursor());
    }

    private <T> InteractionPage<T> descending(
            int limit,
            String cursor,
            List<SocialChronologicalPaginationPlanner.Candidate<T>> candidates) {
        SocialChronologicalPaginationPlanner.Page<T> page =
                chronologicalPaginationPlanner.descending(limit, cursor, candidates);
        return new InteractionPage<>(page.items(), page.hasMore(), page.nextCursor());
    }

    private <T> SocialChronologicalPaginationPlanner.Candidate<T> candidate(
            T item,
            Instant createdAt,
            String id) {
        return new SocialChronologicalPaginationPlanner.Candidate<>(item, createdAt, id);
    }

    record InteractionPage<T>(List<T> items, boolean hasMore, String nextCursor) {
    }
}
