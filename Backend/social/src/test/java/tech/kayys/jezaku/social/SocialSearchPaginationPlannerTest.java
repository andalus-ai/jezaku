package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResult;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialSearchPaginationPlannerTest {
    private final SocialSearchPaginationPlanner planner = new SocialSearchPaginationPlanner();

    @Test
    void paginatesByScoreTypeAndId() {
        List<SocialSearchResult> results = List.of(
                result("users", "user_b", 12.0),
                result("groups", "group_a", 12.0),
                result("users", "user_a", 12.0),
                result("content", "content_a", 20.0),
                result("tags", "tag_a", 5.0));

        SocialSearchPaginationPlanner.Page firstPage = planner.page(2, "", results);
        SocialSearchPaginationPlanner.Page secondPage = planner.page(2, firstPage.nextCursor(), results);
        SocialSearchPaginationPlanner.Page thirdPage = planner.page(2, secondPage.nextCursor(), results);

        assertEquals(List.of("content:content_a", "groups:group_a"), resultKeys(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("users:user_a", "users:user_b"), resultKeys(secondPage));
        assertTrue(secondPage.hasMore());
        assertEquals(List.of("tags:tag_a"), resultKeys(thirdPage));
        assertFalse(thirdPage.hasMore());
        assertEquals("", thirdPage.nextCursor());
    }

    @Test
    void rejectsInvalidCursorPayloads() {
        List<SocialSearchResult> results = List.of(result("users", "user_a", 12.0));

        assertThrows(BadRequestException.class, () -> planner.page(10, "!!!", results));
    }

    private SocialSearchResult result(String resultType, String id, double score) {
        return new SocialSearchResult(
                resultType,
                id,
                id,
                "",
                "",
                "",
                "",
                0,
                0,
                0,
                0,
                score);
    }

    private List<String> resultKeys(SocialSearchPaginationPlanner.Page page) {
        return page.results().stream()
                .map(result -> result.resultType() + ":" + result.id())
                .toList();
    }
}
