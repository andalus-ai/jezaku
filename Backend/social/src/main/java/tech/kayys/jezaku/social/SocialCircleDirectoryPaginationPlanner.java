package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;
import java.util.function.Function;

final class SocialCircleDirectoryPaginationPlanner {
    Page<SocialGroupRecord> groups(int limit, String cursor, List<SocialGroupRecord> groups) {
        Cursor directoryCursor = cursor(cursor);
        List<SocialGroupRecord> pageRecords = safeGroups(groups).stream()
                .sorted(Comparator.comparing(SocialGroupRecord::name)
                        .thenComparing(SocialGroupRecord::groupId))
                .filter(group -> afterCursor(directoryCursorKey(group.name(), group.groupId()), directoryCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageRecords, group -> directoryCursorKey(group.name(), group.groupId()));
    }

    Page<SocialCommunityRecord> communities(int limit, String cursor, List<SocialCommunityRecord> communities) {
        Cursor directoryCursor = cursor(cursor);
        List<SocialCommunityRecord> pageRecords = safeCommunities(communities).stream()
                .sorted(Comparator.comparing(SocialCommunityRecord::name)
                        .thenComparing(SocialCommunityRecord::communityId))
                .filter(community -> afterCursor(
                        directoryCursorKey(community.name(), community.communityId()),
                        directoryCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageRecords, community -> directoryCursorKey(
                community.name(),
                community.communityId()));
    }

    private <T> Page<T> page(int limit, List<T> pageRecords, Function<T, String> cursorKey) {
        boolean hasMore = pageRecords.size() > limit;
        List<T> returnedRecords = hasMore
                ? pageRecords.subList(0, limit)
                : pageRecords;
        String nextCursor = hasMore && !returnedRecords.isEmpty()
                ? encodeCursor(cursorKey.apply(returnedRecords.get(returnedRecords.size() - 1)))
                : "";
        return new Page<>(returnedRecords, hasMore, nextCursor);
    }

    private List<SocialGroupRecord> safeGroups(List<SocialGroupRecord> groups) {
        return groups == null
                ? List.of()
                : groups.stream()
                        .filter(group -> group != null
                                && group.groupId() != null
                                && !group.groupId().isBlank()
                                && group.name() != null)
                        .toList();
    }

    private List<SocialCommunityRecord> safeCommunities(List<SocialCommunityRecord> communities) {
        return communities == null
                ? List.of()
                : communities.stream()
                        .filter(community -> community != null
                                && community.communityId() != null
                                && !community.communityId().isBlank()
                                && community.name() != null)
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

    private String directoryCursorKey(String name, String id) {
        return name + "\u0000" + id;
    }

    record Page<T>(List<T> items, boolean hasMore, String nextCursor) {
    }

    private record Cursor(String key) {
    }
}
