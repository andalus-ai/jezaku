package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentCascadeRemoverTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T14:00:00Z");

    @Test
    void removesAttachedContentGraphStateAndAllCommentShapes() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveContent(content("content_a"));
        repository.saveReaction(new SocialReactionRecord("content_a", "viewer_a", "like", BASE_TIME));
        repository.saveSave(new SocialSaveRecord("content_a", "viewer_a", BASE_TIME));
        repository.saveShare(new SocialShareRecord("share_a", "content_a", "viewer_a", "share", BASE_TIME));
        repository.saveContentHide(new SocialContentHideRecord("content_a", "viewer_a", "hide", BASE_TIME));
        repository.saveContentReport(new SocialContentReportRecord(
                "report_a",
                "content_a",
                "viewer_b",
                "spam",
                "bad",
                "open",
                BASE_TIME,
                BASE_TIME));
        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_a",
                "content_a",
                "group_a",
                "group",
                "owner_a",
                "remove",
                "removed",
                "cleanup",
                BASE_TIME,
                BASE_TIME));
        repository.saveContentTag(new SocialContentTagRecord("content_a", "cleanup", BASE_TIME));
        repository.saveMention(new SocialMentionRecord(
                "mention_a",
                "content_a",
                "reply_a",
                "viewer_a",
                "owner_a",
                "comment",
                BASE_TIME));
        repository.saveActivity(new SocialActivityRecord(
                "activity_a",
                "content_liked",
                "viewer_a",
                "owner_a",
                "content_a",
                "",
                "like",
                "",
                BASE_TIME,
                false));
        repository.saveComment(comment("root_a", ""));
        repository.saveComment(comment("reply_a", "root_a"));
        repository.saveComment(comment("nested_a", "reply_a"));
        repository.saveComment(comment("orphan_a", "missing_parent"));
        repository.saveCommentReaction(new SocialCommentReactionRecord("root_a", "viewer_a", "like", BASE_TIME));
        repository.saveCommentReaction(new SocialCommentReactionRecord("nested_a", "viewer_b", "like", BASE_TIME));
        repository.saveCommentReaction(new SocialCommentReactionRecord("orphan_a", "viewer_c", "like", BASE_TIME));

        new SocialContentCascadeRemover(repository).remove("content_a");

        assertNull(repository.content("content_a"));
        assertTrue(repository.reactions("content_a").isEmpty());
        assertTrue(repository.saves("content_a").isEmpty());
        assertTrue(repository.shares("content_a").isEmpty());
        assertTrue(repository.contentHides("content_a").isEmpty());
        assertTrue(repository.contentReports().isEmpty());
        assertTrue(repository.circleContentModerations().isEmpty());
        assertTrue(repository.contentTags("content_a").isEmpty());
        assertTrue(repository.mentions("content_a").isEmpty());
        assertTrue(repository.activities().isEmpty());
        assertTrue(repository.comments("content_a").isEmpty());
        assertTrue(repository.commentReactions("root_a").isEmpty());
        assertTrue(repository.commentReactions("nested_a").isEmpty());
        assertTrue(repository.commentReactions("orphan_a").isEmpty());
    }

    private static SocialContentRecord content(String contentId) {
        return new SocialContentRecord(
                contentId,
                "owner_a",
                "post",
                "public",
                "",
                "caption",
                BASE_TIME);
    }

    private static SocialCommentRecord comment(String commentId, String parentCommentId) {
        return new SocialCommentRecord(
                commentId,
                "content_a",
                "viewer_a",
                commentId + " text",
                parentCommentId,
                BASE_TIME);
    }
}
