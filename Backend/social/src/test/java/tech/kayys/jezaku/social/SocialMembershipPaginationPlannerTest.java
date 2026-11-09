package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialMembershipPaginationPlannerTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-03T05:00:00Z");

    private final SocialMembershipPaginationPlanner planner = new SocialMembershipPaginationPlanner();

    @Test
    void paginatesTargetMembersByRoleAndMemberId() {
        List<MembershipRecord> memberships = List.of(
                membership("owner_b", "group_a", "owner"),
                membership("member_b", "group_a", "member"),
                membership("admin_a", "group_a", "admin"),
                membership("member_a", "group_a", "member"),
                membership("other_member", "group_b", "member"));

        SocialMembershipPaginationPlanner.Page firstPage =
                planner.targetMembers(2, "", "group_a", memberships);
        SocialMembershipPaginationPlanner.Page secondPage =
                planner.targetMembers(2, firstPage.nextCursor(), "group_a", memberships);

        assertEquals(List.of("admin_a", "member_a"), memberIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("member_b", "owner_b"), memberIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesUserMembershipsByTargetId() {
        List<MembershipRecord> memberships = List.of(
                membership("user_a", "group_c", "member"),
                membership("other_user", "group_a", "member"),
                membership("user_a", "group_a", "owner"),
                membership("user_a", "group_b", "member"));

        SocialMembershipPaginationPlanner.Page firstPage =
                planner.userMemberships(2, "", "user_a", memberships);
        SocialMembershipPaginationPlanner.Page secondPage =
                planner.userMemberships(2, firstPage.nextCursor(), "user_a", memberships);

        assertEquals(List.of("group_a", "group_b"), targetIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("group_c"), targetIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void rejectsInvalidCursorPayloads() {
        List<MembershipRecord> memberships = List.of(membership("user_a", "group_a", "member"));

        assertThrows(BadRequestException.class, () -> planner.targetMembers(10, "!!!", "group_a", memberships));
        assertThrows(BadRequestException.class, () -> planner.userMemberships(10, "!!!", "user_a", memberships));
    }

    private MembershipRecord membership(String memberId, String targetId, String role) {
        return new MembershipRecord(memberId, targetId, role, BASE_TIME);
    }

    private List<String> memberIds(SocialMembershipPaginationPlanner.Page page) {
        return page.memberships().stream().map(MembershipRecord::memberId).toList();
    }

    private List<String> targetIds(SocialMembershipPaginationPlanner.Page page) {
        return page.memberships().stream().map(MembershipRecord::targetId).toList();
    }
}
