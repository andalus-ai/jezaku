package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResult;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;

final class SocialSearchPaginationPlanner {
    Page page(int limit, String cursor, List<SocialSearchResult> results) {
        Cursor searchCursor = cursor(cursor);
        List<SocialSearchResult> pageResults = safeResults(results).stream()
                .sorted(Comparator.comparingDouble(SocialSearchResult::score).reversed()
                        .thenComparing(SocialSearchResult::resultType)
                        .thenComparing(SocialSearchResult::id))
                .filter(result -> afterCursor(result, searchCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageResults);
    }

    private Page page(int limit, List<SocialSearchResult> pageResults) {
        boolean hasMore = pageResults.size() > limit;
        List<SocialSearchResult> returnedResults = hasMore
                ? pageResults.subList(0, limit)
                : pageResults;
        String nextCursor = hasMore && !returnedResults.isEmpty()
                ? cursor(returnedResults.get(returnedResults.size() - 1))
                : "";
        return new Page(returnedResults, hasMore, nextCursor);
    }

    private List<SocialSearchResult> safeResults(List<SocialSearchResult> results) {
        return results == null
                ? List.of()
                : results.stream()
                        .filter(result -> result != null
                                && result.resultType() != null
                                && !result.resultType().isBlank()
                                && result.id() != null
                                && !result.id().isBlank()
                                && Double.isFinite(result.score()))
                        .toList();
    }

    private boolean afterCursor(SocialSearchResult result, Cursor cursor) {
        if (cursor == null) {
            return true;
        }
        int scoreComparison = Double.compare(result.score(), cursor.score());
        if (scoreComparison < 0) {
            return true;
        }
        if (scoreComparison > 0) {
            return false;
        }
        int typeComparison = result.resultType().compareTo(cursor.resultType());
        if (typeComparison > 0) {
            return true;
        }
        if (typeComparison < 0) {
            return false;
        }
        return result.id().compareTo(cursor.id()) > 0;
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
                    decoded.substring(firstSeparator + 1, secondSeparator),
                    decoded.substring(secondSeparator + 1));
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("cursor is invalid");
        }
    }

    private String cursor(SocialSearchResult result) {
        String raw = result.score() + "|" + result.resultType() + "|" + result.id();
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    record Page(List<SocialSearchResult> results, boolean hasMore, String nextCursor) {
    }

    private record Cursor(double score, String resultType, String id) {
    }
}
