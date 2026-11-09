package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialChronologicalPaginationPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    private final SocialChronologicalPaginationPlanner planner = new SocialChronologicalPaginationPlanner();

    @Test
    void paginatesDescendingByCreatedAtAndId() {
        List<SocialChronologicalPaginationPlanner.Candidate<String>> candidates = List.of(
                candidate("same_b", BASE_TIME.plusSeconds(20)),
                candidate("old", BASE_TIME.plusSeconds(10)),
                candidate("same_a", BASE_TIME.plusSeconds(20)));

        SocialChronologicalPaginationPlanner.Page<String> firstPage = planner.descending(2, "", candidates);
        SocialChronologicalPaginationPlanner.Page<String> secondPage =
                planner.descending(2, firstPage.nextCursor(), candidates);

        assertEquals(List.of("same_a", "same_b"), firstPage.items());
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("old"), secondPage.items());
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesAscendingByCreatedAtAndId() {
        List<SocialChronologicalPaginationPlanner.Candidate<String>> candidates = List.of(
                candidate("new", BASE_TIME.plusSeconds(20)),
                candidate("same_b", BASE_TIME.plusSeconds(10)),
                candidate("same_a", BASE_TIME.plusSeconds(10)));

        SocialChronologicalPaginationPlanner.Page<String> firstPage = planner.ascending(2, "", candidates);
        SocialChronologicalPaginationPlanner.Page<String> secondPage =
                planner.ascending(2, firstPage.nextCursor(), candidates);

        assertEquals(List.of("same_a", "same_b"), firstPage.items());
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("new"), secondPage.items());
        assertFalse(secondPage.hasMore());
    }

    @Test
    void rejectsInvalidCursorPayloads() {
        List<SocialChronologicalPaginationPlanner.Candidate<String>> candidates =
                List.of(candidate("item_a", BASE_TIME));

        assertThrows(BadRequestException.class, () -> planner.descending(10, "!!!", candidates));
        assertThrows(BadRequestException.class, () -> planner.ascending(10, "!!!", candidates));
    }

    private SocialChronologicalPaginationPlanner.Candidate<String> candidate(String id, Instant createdAt) {
        return new SocialChronologicalPaginationPlanner.Candidate<>(id, createdAt, id);
    }
}
