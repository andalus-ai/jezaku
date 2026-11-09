package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentInteractionReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T10:30:00Z");

    @Test
    void pagesSharesAndReportsDescendingWithStatusFilter() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveShare(new SocialShareRecord(
                "share_old",
                "content_a",
                "user_a",
                "old",
                BASE_TIME.plusSeconds(10)));
        repository.saveShare(new SocialShareRecord(
                "share_new",
                "content_a",
                "user_b",
                "new",
                BASE_TIME.plusSeconds(20)));
        repository.saveShare(new SocialShareRecord(
                "share_other",
                "content_b",
                "user_c",
                "other",
                BASE_TIME.plusSeconds(30)));
        repository.saveContentReport(report("report_old", "content_a", "open", BASE_TIME.plusSeconds(10)));
        repository.saveContentReport(report("report_reviewed", "content_a", "reviewed", BASE_TIME.plusSeconds(20)));
        repository.saveContentReport(report("report_new", "content_b", "open", BASE_TIME.plusSeconds(30)));
        SocialContentInteractionReadModel readModel = readModel(repository, (mention, userId) -> true);

        SocialContentInteractionReadModel.InteractionPage<SocialShareRecord> firstSharePage =
                readModel.shares("content_a", 1, "");
        SocialContentInteractionReadModel.InteractionPage<SocialShareRecord> secondSharePage =
                readModel.shares("content_a", 1, firstSharePage.nextCursor());
        SocialContentInteractionReadModel.InteractionPage<SocialContentReportRecord> reportPage =
                readModel.reports("open", 10, "");

        assertEquals(List.of("share_new"), shareIds(firstSharePage));
        assertTrue(firstSharePage.hasMore());
        assertEquals(List.of("share_old"), shareIds(secondSharePage));
        assertFalse(secondSharePage.hasMore());
        assertEquals(List.of("report_new", "report_old"), reportIds(reportPage));
    }

    @Test
    void pagesMentionsAndFiltersUserMentionsByVisibility() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveMention(mention("mention_old", "content_a", "mentioned_a", BASE_TIME.plusSeconds(10)));
        repository.saveMention(mention("mention_hidden", "content_a", "mentioned_a", BASE_TIME.plusSeconds(20)));
        repository.saveMention(mention("mention_new", "content_a", "mentioned_a", BASE_TIME.plusSeconds(30)));
        repository.saveMention(mention("mention_other", "content_b", "mentioned_b", BASE_TIME.plusSeconds(40)));
        SocialContentInteractionReadModel readModel = readModel(
                repository,
                (mention, userId) -> !"mention_hidden".equals(mention.mentionId()));

        SocialContentInteractionReadModel.InteractionPage<SocialMentionRecord> firstContentPage =
                readModel.contentMentions("content_a", 2, "");
        SocialContentInteractionReadModel.InteractionPage<SocialMentionRecord> secondContentPage =
                readModel.contentMentions("content_a", 2, firstContentPage.nextCursor());
        SocialContentInteractionReadModel.InteractionPage<SocialMentionRecord> userPage =
                readModel.userMentions("mentioned_a", 10, "");

        assertEquals(List.of("mention_new", "mention_hidden"), mentionIds(firstContentPage));
        assertTrue(firstContentPage.hasMore());
        assertEquals(List.of("mention_old"), mentionIds(secondContentPage));
        assertEquals(List.of("mention_new", "mention_old"), mentionIds(userPage));
    }

    @Test
    void pagesCommentsAscendingAndFiltersByParentComment() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveComment(comment("comment_new", "content_a", "", BASE_TIME.plusSeconds(30)));
        repository.saveComment(comment("comment_old", "content_a", "", BASE_TIME.plusSeconds(10)));
        repository.saveComment(comment("reply_new", "content_a", "comment_old", BASE_TIME.plusSeconds(20)));
        repository.saveComment(comment("comment_other", "content_b", "", BASE_TIME.plusSeconds(5)));
        SocialContentInteractionReadModel readModel = readModel(repository, (mention, userId) -> true);

        SocialContentInteractionReadModel.InteractionPage<SocialCommentRecord> topLevelPage =
                readModel.comments("content_a", "", 10, "");
        SocialContentInteractionReadModel.InteractionPage<SocialCommentRecord> replyPage =
                readModel.comments("content_a", "comment_old", 10, "");

        assertEquals(List.of("comment_old", "comment_new"), commentIds(topLevelPage));
        assertEquals(List.of("reply_new"), commentIds(replyPage));
    }

    private SocialContentInteractionReadModel readModel(
            InMemorySocialGraphRepository repository,
            BiPredicate<SocialMentionRecord, String> mentionVisibleToUser) {
        return new SocialContentInteractionReadModel(
                repository,
                new SocialChronologicalPaginationPlanner(),
                mentionVisibleToUser);
    }

    private SocialContentReportRecord report(String reportId, String contentId, String status, Instant createdAt) {
        return new SocialContentReportRecord(
                reportId,
                contentId,
                "reporter_a",
                "spam",
                reportId + " detail",
                status,
                createdAt,
                createdAt);
    }

    private SocialMentionRecord mention(
            String mentionId,
            String contentId,
            String mentionedUserId,
            Instant createdAt) {
        return new SocialMentionRecord(
                mentionId,
                contentId,
                "",
                "actor_a",
                mentionedUserId,
                "content",
                createdAt);
    }

    private SocialCommentRecord comment(
            String commentId,
            String contentId,
            String parentCommentId,
            Instant createdAt) {
        return new SocialCommentRecord(
                commentId,
                contentId,
                "author_a",
                commentId + " text",
                parentCommentId,
                createdAt);
    }

    private List<String> shareIds(SocialContentInteractionReadModel.InteractionPage<SocialShareRecord> page) {
        return page.items().stream().map(SocialShareRecord::shareId).toList();
    }

    private List<String> reportIds(
            SocialContentInteractionReadModel.InteractionPage<SocialContentReportRecord> page) {
        return page.items().stream().map(SocialContentReportRecord::reportId).toList();
    }

    private List<String> mentionIds(SocialContentInteractionReadModel.InteractionPage<SocialMentionRecord> page) {
        return page.items().stream().map(SocialMentionRecord::mentionId).toList();
    }

    private List<String> commentIds(SocialContentInteractionReadModel.InteractionPage<SocialCommentRecord> page) {
        return page.items().stream().map(SocialCommentRecord::commentId).toList();
    }
}
