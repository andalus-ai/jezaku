package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedItem;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;

final class SocialFeedPlanner {
    SocialFeedResponse page(String viewerId, int limit, String cursor, List<Candidate> candidates) {
        List<Candidate> safeCandidates = candidates == null ? List.of() : candidates;
        Cursor feedCursor = cursor(cursor);
        List<SocialFeedItem> visibleItems = safeCandidates.stream()
                .filter(candidate -> candidate != null && candidate.item() != null)
                .map(Candidate::item)
                .sorted(itemComparator())
                .toList();
        List<SocialFeedItem> cursorItems = cursorItems(visibleItems, feedCursor);
        List<SocialFeedItem> pageItems = cursorItems.stream()
                .limit((long) limit + 1)
                .toList();
        boolean hasMore = pageItems.size() > limit;
        List<SocialFeedItem> returnedItems = hasMore
                ? pageItems.subList(0, limit)
                : pageItems;
        String nextCursor = hasMore && !returnedItems.isEmpty()
                ? cursor(returnedItems.get(returnedItems.size() - 1))
                : "";
        return new SocialFeedResponse(
                viewerId,
                returnedItems.size(),
                limit,
                visibleItems.size(),
                safeCandidates.size() - visibleItems.size(),
                hasMore,
                nextCursor,
                returnedItems);
    }

    private Comparator<SocialFeedItem> itemComparator() {
        return Comparator.comparingDouble(SocialFeedItem::score).reversed()
                .thenComparing(SocialFeedItem::createdAt, Comparator.reverseOrder())
                .thenComparing(SocialFeedItem::contentId);
    }

    private List<SocialFeedItem> cursorItems(List<SocialFeedItem> sortedItems, Cursor cursor) {
        if (cursor == null) {
            return sortedItems;
        }
        for (int index = 0; index < sortedItems.size(); index++) {
            if (sortedItems.get(index).contentId().equals(cursor.contentId())) {
                return sortedItems.subList(index + 1, sortedItems.size());
            }
        }
        return sortedItems.stream()
                .filter(item -> afterCursor(item, cursor))
                .toList();
    }

    private boolean afterCursor(SocialFeedItem item, Cursor cursor) {
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
        int createdComparison = item.createdAt().compareTo(cursor.createdAt());
        if (createdComparison < 0) {
            return true;
        }
        if (createdComparison > 0) {
            return false;
        }
        return item.contentId().compareTo(cursor.contentId()) > 0;
    }

    private Cursor cursor(String cursor) {
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
            return new Cursor(
                    score,
                    Instant.parse(decoded.substring(firstSeparator + 1, secondSeparator)),
                    decoded.substring(secondSeparator + 1));
        } catch (IllegalArgumentException | DateTimeParseException e) {
            throw new BadRequestException("cursor is invalid");
        }
    }

    private String cursor(SocialFeedItem item) {
        String raw = item.score() + "|" + item.createdAt() + "|" + item.contentId();
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    record Candidate(SocialFeedItem item) {
    }

    private record Cursor(double score, Instant createdAt, String contentId) {
    }
}
