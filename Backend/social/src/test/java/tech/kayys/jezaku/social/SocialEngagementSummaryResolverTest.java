package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialEngagementSummaryResolverTest {
    @Test
    void summarizesContentCountsAndViewerState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialEngagementSummaryResolver resolver = new SocialEngagementSummaryResolver(repository);
        Instant now = Instant.parse("2026-06-03T13:00:00Z");

        repository.saveContent(new SocialContentRecord(
                "content_a",
                "owner_a",
                "photo",
                "public",
                "",
                "hello",
                now));
        repository.saveReaction(new SocialReactionRecord("content_a", "viewer_a", "like", now.plusSeconds(1)));
        repository.saveReaction(new SocialReactionRecord("content_a", "viewer_b", "wave", now.plusSeconds(2)));
        repository.saveComment(new SocialCommentRecord(
                "comment_a",
                "content_a",
                "viewer_a",
                "nice",
                "",
                now.plusSeconds(3)));
        repository.saveComment(new SocialCommentRecord(
                "comment_b",
                "content_a",
                "viewer_b",
                "reply",
                "comment_a",
                now.plusSeconds(4)));
        repository.saveSave(new SocialSaveRecord("content_a", "viewer_a", now.plusSeconds(5)));
        repository.saveShare(new SocialShareRecord("share_a", "content_a", "viewer_b", "", now.plusSeconds(6)));

        SocialEngagementSummaryResolver.ContentEngagementSummary summary =
                resolver.content("content_a", "viewer_a");

        assertEquals(1, summary.likeCount());
        assertEquals(2, summary.commentCount());
        assertEquals(1, summary.saveCount());
        assertEquals(1, summary.shareCount());
        assertTrue(summary.viewerLiked());
        assertTrue(summary.viewerSaved());
    }

    @Test
    void summarizesCommentRepliesLikesAndViewerState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialEngagementSummaryResolver resolver = new SocialEngagementSummaryResolver(repository);
        Instant now = Instant.parse("2026-06-03T13:30:00Z");

        repository.saveContent(new SocialContentRecord(
                "content_a",
                "owner_a",
                "post",
                "public",
                "",
                "hello",
                now));
        repository.saveComment(new SocialCommentRecord(
                "comment_a",
                "content_a",
                "viewer_a",
                "nice",
                "",
                now.plusSeconds(1)));
        repository.saveComment(new SocialCommentRecord(
                "comment_reply",
                "content_a",
                "viewer_b",
                "agree",
                "comment_a",
                now.plusSeconds(2)));
        repository.saveCommentReaction(new SocialCommentReactionRecord(
                "comment_a",
                "viewer_b",
                "like",
                now.plusSeconds(3)));
        repository.saveCommentReaction(new SocialCommentReactionRecord(
                "comment_a",
                "viewer_c",
                "wave",
                now.plusSeconds(4)));

        SocialEngagementSummaryResolver.CommentEngagementSummary summary =
                resolver.comment("comment_a", "viewer_b");
        SocialEngagementSummaryResolver.CommentEngagementSummary anonymousSummary =
                resolver.comment("comment_a", "");

        assertEquals(1, summary.replyCount());
        assertEquals(1, summary.likeCount());
        assertTrue(summary.viewerLiked());
        assertFalse(anonymousSummary.viewerLiked());
    }
}
