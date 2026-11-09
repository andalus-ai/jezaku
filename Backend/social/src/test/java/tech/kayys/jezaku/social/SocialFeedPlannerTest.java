package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedItem;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialFeedPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    private final SocialFeedPlanner planner = new SocialFeedPlanner();

    @Test
    void ranksVisibleItemsAndPaginatesWithHiddenCounts() {
        List<SocialFeedPlanner.Candidate> candidates = List.of(
                candidate(item("mid_old", BASE_TIME.plusSeconds(10), 25.0)),
                new SocialFeedPlanner.Candidate(null),
                candidate(item("high", BASE_TIME.plusSeconds(5), 30.0)),
                candidate(item("mid_new", BASE_TIME.plusSeconds(20), 25.0)));

        SocialFeedResponse firstPage = planner.page("viewer_a", 2, "", candidates);
        SocialFeedResponse secondPage = planner.page("viewer_a", 2, firstPage.nextCursor(), candidates);

        assertEquals("viewer_a", firstPage.viewerId());
        assertEquals(2, firstPage.count());
        assertEquals(2, firstPage.limit());
        assertEquals(3, firstPage.visibleCount());
        assertEquals(1, firstPage.hiddenCount());
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("high", "mid_new"), contentIds(firstPage));

        assertEquals(1, secondPage.count());
        assertEquals(List.of("mid_old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void usesStableCreatedAtAndContentIdTieBreakers() {
        List<SocialFeedPlanner.Candidate> candidates = List.of(
                candidate(item("same_b", BASE_TIME, 10.0)),
                candidate(item("same_a", BASE_TIME, 10.0)),
                candidate(item("newer", BASE_TIME.plusSeconds(1), 10.0)));

        SocialFeedResponse response = planner.page("viewer_a", 10, "", candidates);

        assertEquals(List.of("newer", "same_a", "same_b"), contentIds(response));
        assertFalse(response.hasMore());
    }

    @Test
    void rejectsInvalidCursorPayloads() {
        List<SocialFeedPlanner.Candidate> candidates = List.of(candidate(item("content_a", BASE_TIME, 10.0)));

        assertThrows(BadRequestException.class, () -> planner.page("viewer_a", 10, "!!!", candidates));
    }

    private SocialFeedPlanner.Candidate candidate(SocialFeedItem item) {
        return new SocialFeedPlanner.Candidate(item);
    }

    private SocialFeedItem item(String contentId, Instant createdAt, double score) {
        return new SocialFeedItem(
                contentId,
                "owner_a",
                "post",
                "public",
                "",
                contentId + " caption",
                createdAt,
                0,
                0,
                0,
                0,
                false,
                false,
                "friend",
                "public",
                score,
                audience());
    }

    private SocialAudienceDecisionResponse audience() {
        return new SocialAudienceDecisionResponse(
                "owner_a",
                "viewer_a",
                "public",
                "",
                true,
                "public",
                "friend",
                false,
                false,
                false,
                false,
                new VisibilityDecision(
                        "viewer_a",
                        "owner_a",
                        "friend",
                        true,
                        true,
                        true,
                        true,
                        "public"));
    }

    private List<String> contentIds(SocialFeedResponse response) {
        return response.items().stream()
                .map(SocialFeedItem::contentId)
                .toList();
    }
}
