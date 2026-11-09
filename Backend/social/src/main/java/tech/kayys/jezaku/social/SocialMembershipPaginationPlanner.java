package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;
import java.util.function.Function;

final class SocialMembershipPaginationPlanner {
    Page targetMembers(int limit, String cursor, String targetId, List<MembershipRecord> memberships) {
        Cursor membershipCursor = cursor(cursor);
        List<MembershipRecord> pageRecords = safeMemberships(memberships).stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .sorted(Comparator.comparing(MembershipRecord::role)
                        .thenComparing(MembershipRecord::memberId))
                .filter(membership -> afterCursor(targetMembershipCursorKey(membership), membershipCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageRecords, this::targetMembershipCursorKey);
    }

    Page userMemberships(int limit, String cursor, String userId, List<MembershipRecord> memberships) {
        Cursor membershipCursor = cursor(cursor);
        List<MembershipRecord> pageRecords = safeMemberships(memberships).stream()
                .filter(membership -> membership.memberId().equals(userId))
                .sorted(Comparator.comparing(MembershipRecord::targetId))
                .filter(membership -> afterCursor(userMembershipCursorKey(membership), membershipCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageRecords, this::userMembershipCursorKey);
    }

    private Page page(
            int limit,
            List<MembershipRecord> pageRecords,
            Function<MembershipRecord, String> cursorKey) {
        boolean hasMore = pageRecords.size() > limit;
        List<MembershipRecord> returnedRecords = hasMore
                ? pageRecords.subList(0, limit)
                : pageRecords;
        String nextCursor = hasMore && !returnedRecords.isEmpty()
                ? encodeCursor(cursorKey.apply(returnedRecords.get(returnedRecords.size() - 1)))
                : "";
        return new Page(returnedRecords, hasMore, nextCursor);
    }

    private List<MembershipRecord> safeMemberships(List<MembershipRecord> memberships) {
        return memberships == null
                ? List.of()
                : memberships.stream()
                        .filter(membership -> membership != null
                                && membership.memberId() != null
                                && membership.targetId() != null
                                && membership.role() != null)
                        .toList();
    }

    private boolean afterCursor(String key, Cursor cursor) {
        return cursor == null || key.compareTo(cursor.key()) > 0;
    }

    private Cursor cursor(String cursor) {
        String normalized = cursor == null ? "" : cursor.trim();
        if (normalized.isEmpty()) {
            return null;
        }
        try {
            String decoded = new String(Base64.getUrlDecoder().decode(normalized), StandardCharsets.UTF_8);
            if (decoded.isEmpty()) {
                throw new BadRequestException("cursor is invalid");
            }
            return new Cursor(decoded);
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("cursor is invalid");
        }
    }

    private String encodeCursor(String key) {
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(key.getBytes(StandardCharsets.UTF_8));
    }

    private String targetMembershipCursorKey(MembershipRecord membership) {
        return membership.role() + "|" + membership.memberId();
    }

    private String userMembershipCursorKey(MembershipRecord membership) {
        return membership.targetId();
    }

    record Page(List<MembershipRecord> memberships, boolean hasMore, String nextCursor) {
    }

    private record Cursor(String key) {
    }
}
