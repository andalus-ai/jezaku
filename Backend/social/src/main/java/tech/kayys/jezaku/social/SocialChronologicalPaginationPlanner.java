package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;

final class SocialChronologicalPaginationPlanner {
    <T> Page<T> descending(int limit, String cursor, List<Candidate<T>> candidates) {
        Cursor chronologicalCursor = cursor(cursor);
        List<Candidate<T>> pageItems = safeCandidates(candidates).stream()
                .sorted(descendingComparator())
                .filter(candidate -> afterDescendingCursor(candidate, chronologicalCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageItems);
    }

    <T> Page<T> ascending(int limit, String cursor, List<Candidate<T>> candidates) {
        Cursor chronologicalCursor = cursor(cursor);
        List<Candidate<T>> pageItems = safeCandidates(candidates).stream()
                .sorted(ascendingComparator())
                .filter(candidate -> afterAscendingCursor(candidate, chronologicalCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageItems);
    }

    private <T> Page<T> page(int limit, List<Candidate<T>> pageItems) {
        boolean hasMore = pageItems.size() > limit;
        List<Candidate<T>> returnedItems = hasMore
                ? pageItems.subList(0, limit)
                : pageItems;
        String nextCursor = hasMore && !returnedItems.isEmpty()
                ? cursor(returnedItems.get(returnedItems.size() - 1))
                : "";
        return new Page<>(returnedItems.stream()
                .map(Candidate::item)
                .toList(), hasMore, nextCursor);
    }

    private <T> List<Candidate<T>> safeCandidates(List<Candidate<T>> candidates) {
        return candidates == null
                ? List.of()
                : candidates.stream()
                        .filter(candidate -> candidate != null
                                && candidate.item() != null
                                && candidate.createdAt() != null
                                && candidate.id() != null
                                && !candidate.id().isBlank())
                        .toList();
    }

    private <T> Comparator<Candidate<T>> descendingComparator() {
        return Comparator.<Candidate<T>, Instant>comparing(Candidate::createdAt, Comparator.reverseOrder())
                .thenComparing(Candidate::id);
    }

    private <T> Comparator<Candidate<T>> ascendingComparator() {
        return Comparator.<Candidate<T>, Instant>comparing(Candidate::createdAt)
                .thenComparing(Candidate::id);
    }

    private <T> boolean afterDescendingCursor(Candidate<T> candidate, Cursor cursor) {
        if (cursor == null) {
            return true;
        }
        int createdComparison = candidate.createdAt().compareTo(cursor.createdAt());
        if (createdComparison < 0) {
            return true;
        }
        if (createdComparison > 0) {
            return false;
        }
        return candidate.id().compareTo(cursor.id()) > 0;
    }

    private <T> boolean afterAscendingCursor(Candidate<T> candidate, Cursor cursor) {
        if (cursor == null) {
            return true;
        }
        int createdComparison = candidate.createdAt().compareTo(cursor.createdAt());
        if (createdComparison > 0) {
            return true;
        }
        if (createdComparison < 0) {
            return false;
        }
        return candidate.id().compareTo(cursor.id()) > 0;
    }

    private Cursor cursor(String cursor) {
        String normalized = cursor == null ? "" : cursor.trim();
        if (normalized.isEmpty()) {
            return null;
        }
        try {
            String decoded = new String(Base64.getUrlDecoder().decode(normalized), StandardCharsets.UTF_8);
            int separator = decoded.indexOf('|');
            if (separator <= 0 || separator == decoded.length() - 1) {
                throw new BadRequestException("cursor is invalid");
            }
            return new Cursor(
                    Instant.parse(decoded.substring(0, separator)),
                    decoded.substring(separator + 1));
        } catch (IllegalArgumentException | DateTimeParseException e) {
            throw new BadRequestException("cursor is invalid");
        }
    }

    private <T> String cursor(Candidate<T> candidate) {
        String raw = candidate.createdAt() + "|" + candidate.id();
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    record Candidate<T>(T item, Instant createdAt, String id) {
    }

    record Page<T>(List<T> items, boolean hasMore, String nextCursor) {
    }

    private record Cursor(Instant createdAt, String id) {
    }
}
