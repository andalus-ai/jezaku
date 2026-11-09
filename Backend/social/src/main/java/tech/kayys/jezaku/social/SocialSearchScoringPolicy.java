package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.Locale;

final class SocialSearchScoringPolicy {
    double userScore(
            double textMatchScore,
            SocialRelationshipContextResponse context,
            int followerCount,
            int visibleContentCount) {
        return textMatchScore
                + Math.min(30.0, context.affinityScore() / 4.0)
                + Math.min(12.0, followerCount)
                + Math.min(10.0, visibleContentCount * 2.0);
    }

    double circleScore(double textMatchScore, boolean viewerMember, int memberCount, int visibleContentCount) {
        return textMatchScore
                + (viewerMember ? 25.0 : 0.0)
                + Math.min(12.0, memberCount)
                + Math.min(10.0, visibleContentCount * 2.0);
    }

    double tagScore(double textMatchScore, int visibleContentCount, int followerCount) {
        return textMatchScore
                + Math.min(20.0, visibleContentCount * 4.0)
                + Math.min(10.0, followerCount);
    }

    boolean matches(String needle, String... values) {
        for (String value : values) {
            if (value != null && value.toLowerCase(Locale.ROOT).contains(needle)) {
                return true;
            }
        }
        return false;
    }

    double textMatchScore(String needle, String... values) {
        double score = 0.0;
        for (String value : values) {
            if (value == null || value.isBlank()) {
                continue;
            }
            String haystack = value.toLowerCase(Locale.ROOT);
            if (haystack.equals(needle)) {
                score = Math.max(score, 100.0);
            } else if (haystack.startsWith(needle)) {
                score = Math.max(score, 80.0);
            } else if (haystack.contains(" " + needle)) {
                score = Math.max(score, 65.0);
            } else if (haystack.contains(needle)) {
                score = Math.max(score, 50.0);
            }
        }
        return score;
    }
}
