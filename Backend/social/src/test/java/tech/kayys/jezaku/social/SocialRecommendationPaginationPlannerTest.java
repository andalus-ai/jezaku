package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRecommendationPaginationPlannerTest {
    private final SocialRecommendationPaginationPlanner planner = new SocialRecommendationPaginationPlanner();

    @Test
    void paginatesByScoreDescendingAndUserId() {
        List<SocialRecommendationPlanner.Candidate> candidates = List.of(
                candidate("candidate_c", 8.0),
                candidate("candidate_b", 12.0),
                candidate("candidate_a", 12.0),
                candidate("candidate_d", 5.0));

        SocialRecommendationPaginationPlanner.Page firstPage = planner.page(2, "", candidates);
        SocialRecommendationPaginationPlanner.Page secondPage =
                planner.page(2, firstPage.nextCursor(), candidates);

        assertEquals(List.of("candidate_a", "candidate_b"), userIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("candidate_c", "candidate_d"), userIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void rejectsInvalidCursorPayloads() {
        List<SocialRecommendationPlanner.Candidate> candidates = List.of(candidate("candidate_a", 12.0));

        assertThrows(BadRequestException.class, () -> planner.page(10, "!!!", candidates));
    }

    private SocialRecommendationPlanner.Candidate candidate(String userId, double score) {
        return new SocialRecommendationPlanner.Candidate(
                userId,
                "mutual_friends",
                1,
                0,
                0,
                0,
                false,
                false,
                score,
                List.of("bridge"),
                List.of(),
                List.of(),
                List.of());
    }

    private List<String> userIds(SocialRecommendationPaginationPlanner.Page page) {
        return page.candidates().stream().map(SocialRecommendationPlanner.Candidate::userId).toList();
    }
}
