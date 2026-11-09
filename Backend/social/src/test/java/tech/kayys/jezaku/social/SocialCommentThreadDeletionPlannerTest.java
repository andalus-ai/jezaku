package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialCommentThreadDeletionPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T13:00:00Z");

    @Test
    void plansRepliesBeforeParents() {
        SocialCommentThreadDeletionPlanner planner = new SocialCommentThreadDeletionPlanner();
        List<SocialCommentRecord> comments = List.of(
                comment("root", ""),
                comment("reply_a", "root"),
                comment("reply_b", "root"),
                comment("reply_c", "reply_a"),
                comment("outside", ""));

        List<String> order = planner.deletionOrder(comments, "root");

        assertEquals(List.of("reply_c", "reply_b", "reply_a", "root"), order);
    }

    @Test
    void stopsTraversalWhenMalformedThreadContainsCycle() {
        SocialCommentThreadDeletionPlanner planner = new SocialCommentThreadDeletionPlanner();
        List<SocialCommentRecord> comments = List.of(
                comment("reply_a", "reply_b"),
                comment("reply_b", "reply_a"));

        List<String> order = planner.deletionOrder(comments, "reply_a");

        assertEquals(List.of("reply_b", "reply_a"), order);
    }

    private static SocialCommentRecord comment(String commentId, String parentCommentId) {
        return new SocialCommentRecord(
                commentId,
                "content_a",
                "author_a",
                commentId + " text",
                parentCommentId,
                BASE_TIME);
    }
}
