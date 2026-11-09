package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleDirectoryPaginationPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    private final SocialCircleDirectoryPaginationPlanner planner = new SocialCircleDirectoryPaginationPlanner();

    @Test
    void paginatesGroupsByNameAndId() {
        List<SocialGroupRecord> groups = List.of(
                group("group_c", "Zine Club"),
                group("group_b", "Camera Club"),
                group("group_a", "Camera Club"),
                group("group_hidden", "Aardvark Club"));

        SocialCircleDirectoryPaginationPlanner.Page<SocialGroupRecord> firstPage =
                planner.groups(2, "", groups);
        SocialCircleDirectoryPaginationPlanner.Page<SocialGroupRecord> secondPage =
                planner.groups(2, firstPage.nextCursor(), groups);

        assertEquals(List.of("group_hidden", "group_a"), groupIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("group_b", "group_c"), groupIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesCommunitiesByNameAndId() {
        List<SocialCommunityRecord> communities = List.of(
                community("community_c", "Street Walks"),
                community("community_b", "AR Makers"),
                community("community_a", "AR Makers"));

        SocialCircleDirectoryPaginationPlanner.Page<SocialCommunityRecord> firstPage =
                planner.communities(2, "", communities);
        SocialCircleDirectoryPaginationPlanner.Page<SocialCommunityRecord> secondPage =
                planner.communities(2, firstPage.nextCursor(), communities);

        assertEquals(List.of("community_a", "community_b"), communityIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("community_c"), communityIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void rejectsInvalidCursorPayloads() {
        List<SocialGroupRecord> groups = List.of(group("group_a", "Alpha"));
        List<SocialCommunityRecord> communities = List.of(community("community_a", "Alpha"));

        assertThrows(BadRequestException.class, () -> planner.groups(10, "!!!", groups));
        assertThrows(BadRequestException.class, () -> planner.communities(10, "!!!", communities));
    }

    private SocialGroupRecord group(String groupId, String name) {
        return new SocialGroupRecord(groupId, name, "public", BASE_TIME);
    }

    private SocialCommunityRecord community(String communityId, String name) {
        return new SocialCommunityRecord(communityId, name, "public", BASE_TIME);
    }

    private List<String> groupIds(SocialCircleDirectoryPaginationPlanner.Page<SocialGroupRecord> page) {
        return page.items().stream().map(SocialGroupRecord::groupId).toList();
    }

    private List<String> communityIds(SocialCircleDirectoryPaginationPlanner.Page<SocialCommunityRecord> page) {
        return page.items().stream().map(SocialCommunityRecord::communityId).toList();
    }
}
