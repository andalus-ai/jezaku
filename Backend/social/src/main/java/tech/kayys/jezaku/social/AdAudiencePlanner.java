package tech.kayys.jezaku.social;

import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.function.BiPredicate;
import java.util.function.Function;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceSegment;

final class AdAudiencePlanner {
    private static final List<String> RELATION_ORDER = List.of(
            "close_friend",
            "friend",
            "family",
            "friend_of_friend",
            "shared_group",
            "shared_community",
            "follower",
            "public");

    private AdAudiencePlanner() {
    }

    static SocialAdAudiencePreviewResponse preview(
            String advertiserId,
            String objective,
            int maxDepth,
            int limit,
            Set<String> targetTags,
            Set<String> targetGroupIds,
            Set<String> targetCommunityIds,
            Iterable<String> knownUserIds,
            BiPredicate<String, String> blockedEitherWay,
            Function<String, SocialAdAudienceCandidate> candidateResolver) {
        List<SocialAdAudienceCandidate> candidates = new java.util.ArrayList<>();
        int blockedExcludedCount = 0;
        for (String candidateUserId : knownUserIds) {
            if (candidateUserId.equals(advertiserId)) {
                continue;
            }
            if (blockedEitherWay.test(advertiserId, candidateUserId)) {
                blockedExcludedCount++;
                continue;
            }
            SocialAdAudienceCandidate candidate = candidateResolver.apply(candidateUserId);
            if (candidate != null) {
                candidates.add(candidate);
            }
        }

        List<SocialAdAudienceCandidate> rankedCandidates = candidates.stream()
                .sorted(Comparator.comparingDouble(SocialAdAudienceCandidate::relevanceScore).reversed()
                        .thenComparing(Comparator.comparingDouble(SocialAdAudienceCandidate::affinityScore)
                                .reversed())
                        .thenComparing(SocialAdAudienceCandidate::userId))
                .toList();
        List<SocialAdAudienceCandidate> returned = rankedCandidates.stream()
                .limit(limit)
                .toList();
        return new SocialAdAudiencePreviewResponse(
                advertiserId,
                objective,
                maxDepth,
                limit,
                rankedCandidates.size(),
                returned.size(),
                blockedExcludedCount,
                targetTags.size(),
                targetGroupIds.size(),
                targetCommunityIds.size(),
                segments(rankedCandidates, limit),
                returned);
    }

    static int audienceDepth(int connectionDepth, Set<String> relations) {
        int relationDepth = relations.stream()
                .mapToInt(AdAudiencePlanner::relationDepth)
                .min()
                .orElse(3);
        return connectionDepth >= 0 ? Math.min(connectionDepth, relationDepth) : relationDepth;
    }

    static List<String> sortedRelations(Set<String> relations) {
        return relations.stream()
                .sorted(Comparator.comparingInt(AdAudiencePlanner::relationPriority)
                        .thenComparing(relation -> relation))
                .toList();
    }

    static int metricRelationPriority(String relation) {
        if ("unmatched".equals(relation)) {
            return 1_000;
        }
        return relationPriority(relation);
    }

    static double relevanceScore(
            double affinityScore,
            String primaryRelation,
            List<String> relations,
            List<String> matchedTags,
            List<String> matchedGroupIds,
            List<String> matchedCommunityIds,
            int visibleContentCount) {
        double score = affinityScore
                + relationBoost(primaryRelation)
                + (Math.min(relations.size(), 4) * 2.0)
                + (matchedTags.size() * 12.0)
                + (matchedGroupIds.size() * 8.0)
                + (matchedCommunityIds.size() * 6.0)
                + (Math.min(visibleContentCount, 5) * 1.5);
        return Math.min(100.0, score);
    }

    static List<String> reasons(
            String primaryRelation,
            List<String> relations,
            List<String> matchedTags,
            List<String> matchedGroupIds,
            List<String> matchedCommunityIds,
            int visibleContentCount) {
        LinkedHashSet<String> reasons = new LinkedHashSet<>();
        reasons.add("relation:" + primaryRelation);
        if (relations.contains("follower")) {
            reasons.add("follows_advertiser");
        }
        if (!matchedTags.isEmpty()) {
            reasons.add("target_tags");
        }
        if (!matchedGroupIds.isEmpty()) {
            reasons.add("target_groups");
        }
        if (!matchedCommunityIds.isEmpty()) {
            reasons.add("target_communities");
        }
        if (visibleContentCount > 0) {
            reasons.add("visible_creator_activity");
        }
        return List.copyOf(reasons);
    }

    private static int relationDepth(String relation) {
        return switch (relation) {
            case "close_friend", "friend", "family", "follower" -> 1;
            case "friend_of_friend", "shared_group", "shared_community" -> 2;
            default -> 3;
        };
    }

    private static int relationPriority(String relation) {
        return switch (relation) {
            case "close_friend" -> 0;
            case "friend" -> 1;
            case "family" -> 2;
            case "friend_of_friend" -> 3;
            case "shared_group" -> 4;
            case "shared_community" -> 5;
            case "follower" -> 6;
            default -> 7;
        };
    }

    private static double relationBoost(String relation) {
        return switch (relation) {
            case "close_friend" -> 18.0;
            case "friend" -> 14.0;
            case "family" -> 12.0;
            case "friend_of_friend" -> 8.0;
            case "shared_group" -> 7.0;
            case "shared_community" -> 6.0;
            case "follower" -> 6.0;
            default -> 1.0;
        };
    }

    private static List<SocialAdAudienceSegment> segments(
            List<SocialAdAudienceCandidate> candidates,
            int userIdLimit) {
        return RELATION_ORDER.stream()
                .map(relation -> segment(relation, candidates, userIdLimit))
                .filter(segment -> segment.count() > 0)
                .toList();
    }

    private static SocialAdAudienceSegment segment(
            String relation,
            List<SocialAdAudienceCandidate> candidates,
            int userIdLimit) {
        List<String> userIds = candidates.stream()
                .filter(candidate -> candidate.primaryRelation().equals(relation))
                .map(SocialAdAudienceCandidate::userId)
                .limit(userIdLimit)
                .toList();
        int count = (int) candidates.stream()
                .filter(candidate -> candidate.primaryRelation().equals(relation))
                .count();
        return new SocialAdAudienceSegment(relation, count, userIds);
    }
}
