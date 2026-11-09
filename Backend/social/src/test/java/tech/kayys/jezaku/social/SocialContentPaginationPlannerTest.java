package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialContentPaginationPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    private final SocialContentPaginationPlanner planner = new SocialContentPaginationPlanner();

    @Test
    void paginatesTimelineByCursorTimestampAndContentId() {
        List<SocialContentPaginationPlanner.ContentCandidate> candidates = List.of(
                timelineCandidate("same_b", BASE_TIME.plusSeconds(20)),
                timelineCandidate("old", BASE_TIME.plusSeconds(10)),
                timelineCandidate("same_a", BASE_TIME.plusSeconds(20)));

        SocialContentPaginationPlanner.Page firstPage = planner.timeline(2, "", candidates);
        SocialContentPaginationPlanner.Page secondPage = planner.timeline(2, firstPage.nextCursor(), candidates);

        assertEquals(List.of("same_a", "same_b"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesRankedContentByScoreCreatedAtAndContentId() {
        List<SocialContentPaginationPlanner.RankedCandidate> candidates = List.of(
                rankedCandidate("tie_old", BASE_TIME.plusSeconds(10), 20.0),
                rankedCandidate("high", BASE_TIME.plusSeconds(5), 30.0),
                rankedCandidate("tie_new", BASE_TIME.plusSeconds(20), 20.0));

        SocialContentPaginationPlanner.Page firstPage = planner.ranked(2, "", candidates);
        SocialContentPaginationPlanner.Page secondPage = planner.ranked(2, firstPage.nextCursor(), candidates);

        assertEquals(List.of("high", "tie_new"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("tie_old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void rejectsInvalidTimelineAndRankedCursors() {
        List<SocialContentPaginationPlanner.ContentCandidate> timelineCandidates =
                List.of(timelineCandidate("content_a", BASE_TIME));
        List<SocialContentPaginationPlanner.RankedCandidate> rankedCandidates =
                List.of(rankedCandidate("content_a", BASE_TIME, 10.0));

        assertThrows(BadRequestException.class, () -> planner.timeline(10, "!!!", timelineCandidates));
        assertThrows(BadRequestException.class, () -> planner.ranked(10, "!!!", rankedCandidates));
    }

    private SocialContentPaginationPlanner.ContentCandidate timelineCandidate(String contentId, Instant cursorAt) {
        return new SocialContentPaginationPlanner.ContentCandidate(content(contentId, cursorAt), cursorAt);
    }

    private SocialContentPaginationPlanner.RankedCandidate rankedCandidate(
            String contentId,
            Instant createdAt,
            double score) {
        return new SocialContentPaginationPlanner.RankedCandidate(content(contentId, createdAt), score);
    }

    private SocialContentRecord content(String contentId, Instant createdAt) {
        return new SocialContentRecord(
                contentId,
                "owner_a",
                "post",
                "public",
                "",
                contentId + " caption",
                createdAt);
    }

    private List<String> contentIds(SocialContentPaginationPlanner.Page page) {
        return page.contents().stream()
                .map(SocialContentRecord::contentId)
                .toList();
    }
}
