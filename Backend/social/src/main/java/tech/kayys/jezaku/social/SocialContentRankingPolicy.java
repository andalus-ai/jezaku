package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;

final class SocialContentRankingPolicy {
    private static final double LIKE_WEIGHT = 1.5;
    private static final double COMMENT_WEIGHT = 2.0;
    private static final double SAVE_WEIGHT = 1.0;
    private static final double SHARE_WEIGHT = 3.0;
    private static final double TOPIC_MATCH_WEIGHT = 10.0;
    private static final double SEARCH_ENGAGEMENT_CAP = 20.0;

    private final Clock clock;

    SocialContentRankingPolicy() {
        this(Clock.systemUTC());
    }

    SocialContentRankingPolicy(Clock clock) {
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    double feedScore(
            SocialContentRecord content,
            SocialRelationshipContextResponse context,
            SocialEngagementSummaryResolver.ContentEngagementSummary engagement) {
        return context.affinityScore()
                + scopeBoost(content.scope())
                + engagementScore(engagement)
                + recencyBoost(content.createdAt());
    }

    double contentSearchScore(
            double textMatchScore,
            SocialContentRecord content,
            SocialEngagementSummaryResolver.ContentEngagementSummary engagement) {
        return textMatchScore
                + Math.min(SEARCH_ENGAGEMENT_CAP, engagementSearchScore(engagement))
                + recencyBoost(content.createdAt());
    }

    double trendingContribution(
            SocialContentRecord content,
            SocialEngagementSummaryResolver.ContentEngagementSummary engagement) {
        return 1.0
                + engagementScore(engagement)
                + recencyBoost(content.createdAt());
    }

    double topicFeedScore(
            SocialContentRecord content,
            int matchedTagCount,
            SocialEngagementSummaryResolver.ContentEngagementSummary engagement) {
        return (matchedTagCount * TOPIC_MATCH_WEIGHT)
                + engagementScore(engagement)
                + recencyBoost(content.createdAt());
    }

    private double engagementScore(SocialEngagementSummaryResolver.ContentEngagementSummary engagement) {
        return (engagement.likeCount() * LIKE_WEIGHT)
                + (engagement.commentCount() * COMMENT_WEIGHT)
                + (engagement.saveCount() * SAVE_WEIGHT)
                + (engagement.shareCount() * SHARE_WEIGHT);
    }

    private double engagementSearchScore(SocialEngagementSummaryResolver.ContentEngagementSummary engagement) {
        return engagement.likeCount()
                + (engagement.commentCount() * COMMENT_WEIGHT)
                + engagement.saveCount()
                + (engagement.shareCount() * SHARE_WEIGHT);
    }

    private double scopeBoost(String scope) {
        return switch (scope) {
            case "close_friends" -> 12.0;
            case "family" -> 10.0;
            case "friends" -> 8.0;
            case "group" -> 6.0;
            case "community" -> 5.0;
            case "private" -> 3.0;
            default -> 1.0;
        };
    }

    private double recencyBoost(Instant createdAt) {
        long ageSeconds = Math.max(0, clock.instant().getEpochSecond() - createdAt.getEpochSecond());
        double ageDays = ageSeconds / 86_400.0;
        return Math.max(0.0, 5.0 - Math.min(5.0, ageDays));
    }
}
