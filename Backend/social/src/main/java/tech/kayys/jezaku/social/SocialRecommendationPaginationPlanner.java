package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Comparator;
import java.util.List;

final class SocialRecommendationPaginationPlanner {
    Page page(int limit, String cursor, List<SocialRecommendationPlanner.Candidate> candidates) {
        Cursor recommendationCursor = cursor(cursor);
        List<SocialRecommendationPlanner.Candidate> pageCandidates = safeCandidates(candidates).stream()
                .sorted(Comparator.comparingDouble(SocialRecommendationPlanner.Candidate::score).reversed()
                        .thenComparing(SocialRecommendationPlanner.Candidate::userId))
                .filter(candidate -> afterCursor(candidate, recommendationCursor))
                .limit((long) limit + 1)
                .toList();
        return page(limit, pageCandidates);
    }

    private Page page(int limit, List<SocialRecommendationPlanner.Candidate> pageCandidates) {
        boolean hasMore = pageCandidates.size() > limit;
        List<SocialRecommendationPlanner.Candidate> returnedCandidates = hasMore
                ? pageCandidates.subList(0, limit)
                : pageCandidates;
        String nextCursor = hasMore && !returnedCandidates.isEmpty()
                ? cursor(returnedCandidates.get(returnedCandidates.size() - 1))
                : "";
        return new Page(returnedCandidates, hasMore, nextCursor);
    }

    private List<SocialRecommendationPlanner.Candidate> safeCandidates(
            List<SocialRecommendationPlanner.Candidate> candidates) {
        return candidates == null
                ? List.of()
                : candidates.stream()
                        .filter(candidate -> candidate != null
                                && candidate.userId() != null
                                && !candidate.userId().isBlank()
                                && Double.isFinite(candidate.score()))
                        .toList();
    }

    private boolean afterCursor(SocialRecommendationPlanner.Candidate candidate, Cursor cursor) {
        if (cursor == null) {
            return true;
        }
        int scoreComparison = Double.compare(candidate.score(), cursor.score());
        if (scoreComparison < 0) {
            return true;
        }
        if (scoreComparison > 0) {
            return false;
        }
        return candidate.userId().compareTo(cursor.userId()) > 0;
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
            double score = Double.parseDouble(decoded.substring(0, separator));
            if (!Double.isFinite(score)) {
                throw new BadRequestException("cursor is invalid");
            }
            return new Cursor(score, decoded.substring(separator + 1));
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("cursor is invalid");
        }
    }

    private String cursor(SocialRecommendationPlanner.Candidate candidate) {
        String raw = candidate.score() + "|" + candidate.userId();
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    record Page(
            List<SocialRecommendationPlanner.Candidate> candidates,
            boolean hasMore,
            String nextCursor) {
    }

    private record Cursor(double score, String userId) {
    }
}
