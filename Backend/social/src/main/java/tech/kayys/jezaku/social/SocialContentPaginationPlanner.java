package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;

final class SocialContentPaginationPlanner {
    Page timeline(int limit, String cursor, List<ContentCandidate> candidates) {
        Cursor contentCursor = cursor(cursor);
        List<ContentCandidate> pageItems = safeContentCandidates(candidates).stream()
                .sorted(contentComparator())
                .filter(item -> afterContentCursor(item, contentCursor))
                .limit((long) limit + 1)
                .toList();
        boolean hasMore = pageItems.size() > limit;
        List<ContentCandidate> returnedItems = hasMore
                ? pageItems.subList(0, limit)
                : pageItems;
        String nextCursor = hasMore && !returnedItems.isEmpty()
                ? cursor(returnedItems.get(returnedItems.size() - 1))
                : "";
        return new Page(returnedItems.stream()
                .map(ContentCandidate::content)
                .toList(), hasMore, nextCursor);
    }

    Page ranked(int limit, String cursor, List<RankedCandidate> candidates) {
        RankedCursor rankedCursor = rankedCursor(cursor);
        List<RankedCandidate> sortedItems = safeRankedCandidates(candidates).stream()
                .sorted(rankedComparator())
                .toList();
        List<RankedCandidate> cursorItems = rankedCursorItems(sortedItems, rankedCursor);
        List<RankedCandidate> pageItems = cursorItems.stream()
                .limit((long) limit + 1)
                .toList();
        boolean hasMore = pageItems.size() > limit;
        List<RankedCandidate> returnedItems = hasMore
                ? pageItems.subList(0, limit)
                : pageItems;
        String nextCursor = hasMore && !returnedItems.isEmpty()
                ? rankedCursor(returnedItems.get(returnedItems.size() - 1))
                : "";
        return new Page(returnedItems.stream()
                .map(RankedCandidate::content)
                .toList(), hasMore, nextCursor);
    }

    private List<ContentCandidate> safeContentCandidates(List<ContentCandidate> candidates) {
        return candidates == null
                ? List.of()
                : candidates.stream()
                        .filter(candidate -> candidate != null && candidate.content() != null)
                        .toList();
    }

    private List<RankedCandidate> safeRankedCandidates(List<RankedCandidate> candidates) {
        return candidates == null
                ? List.of()
                : candidates.stream()
                        .filter(candidate -> candidate != null && candidate.content() != null)
                        .filter(candidate -> Double.isFinite(candidate.score()))
                        .toList();
    }

    private Comparator<ContentCandidate> contentComparator() {
        return Comparator.comparing(ContentCandidate::cursorCreatedAt, Comparator.reverseOrder())
                .thenComparing(item -> item.content().contentId());
    }

    private Comparator<RankedCandidate> rankedComparator() {
        return Comparator.comparingDouble(RankedCandidate::score).reversed()
                .thenComparing(item -> item.content().createdAt(), Comparator.reverseOrder())
                .thenComparing(item -> item.content().contentId());
    }

    private List<RankedCandidate> rankedCursorItems(List<RankedCandidate> sortedItems, RankedCursor cursor) {
        if (cursor == null) {
            return sortedItems;
        }
        for (int index = 0; index < sortedItems.size(); index++) {
            if (sortedItems.get(index).content().contentId().equals(cursor.contentId())) {
                return sortedItems.subList(index + 1, sortedItems.size());
            }
        }
        return sortedItems.stream()
                .filter(item -> afterRankedCursor(item, cursor))
                .toList();
    }

    private boolean afterContentCursor(ContentCandidate item, Cursor cursor) {
        if (cursor == null) {
            return true;
        }
        int createdComparison = item.cursorCreatedAt().compareTo(cursor.createdAt());
        if (createdComparison < 0) {
            return true;
        }
        if (createdComparison > 0) {
            return false;
        }
        return item.content().contentId().compareTo(cursor.contentId()) > 0;
    }

    private boolean afterRankedCursor(RankedCandidate item, RankedCursor cursor) {
        if (cursor == null) {
            return true;
        }
        int scoreComparison = Double.compare(item.score(), cursor.score());
        if (scoreComparison < 0) {
            return true;
        }
        if (scoreComparison > 0) {
            return false;
        }
        int createdComparison = item.content().createdAt().compareTo(cursor.createdAt());
        if (createdComparison < 0) {
            return true;
        }
        if (createdComparison > 0) {
            return false;
        }
        return item.content().contentId().compareTo(cursor.contentId()) > 0;
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

    private String cursor(ContentCandidate item) {
        String raw = item.cursorCreatedAt() + "|" + item.content().contentId();
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    private RankedCursor rankedCursor(String cursor) {
        String normalized = cursor == null ? "" : cursor.trim();
        if (normalized.isEmpty()) {
            return null;
        }
        try {
            String decoded = new String(Base64.getUrlDecoder().decode(normalized), StandardCharsets.UTF_8);
            int firstSeparator = decoded.indexOf('|');
            int secondSeparator = decoded.indexOf('|', firstSeparator + 1);
            if (firstSeparator <= 0 || secondSeparator <= firstSeparator + 1
                    || secondSeparator == decoded.length() - 1) {
                throw new BadRequestException("cursor is invalid");
            }
            double score = Double.parseDouble(decoded.substring(0, firstSeparator));
            if (!Double.isFinite(score)) {
                throw new BadRequestException("cursor is invalid");
            }
            return new RankedCursor(
                    score,
                    Instant.parse(decoded.substring(firstSeparator + 1, secondSeparator)),
                    decoded.substring(secondSeparator + 1));
        } catch (IllegalArgumentException | DateTimeParseException e) {
            throw new BadRequestException("cursor is invalid");
        }
    }

    private String rankedCursor(RankedCandidate item) {
        String raw = item.score() + "|" + item.content().createdAt() + "|" + item.content().contentId();
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    record ContentCandidate(SocialContentRecord content, Instant cursorCreatedAt) {
    }

    record RankedCandidate(SocialContentRecord content, double score) {
    }

    record Page(List<SocialContentRecord> contents, boolean hasMore, String nextCursor) {
    }

    private record Cursor(Instant createdAt, String contentId) {
    }

    private record RankedCursor(double score, Instant createdAt, String contentId) {
    }
}
