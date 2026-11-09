package tech.kayys.jezaku.social;

import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

final class SocialRecommendationPlanner {
    private final SocialGraphRepository repository;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialGraphTraversalIndex traversalIndex;

    SocialRecommendationPlanner(SocialGraphRepository repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.relationshipPolicy = new SocialRelationshipPolicy(this.repository);
        this.traversalIndex = new SocialGraphTraversalIndex(this.repository, relationshipPolicy);
    }

    List<Candidate> recommendations(String userId) {
        return rankedCandidates(userId);
    }

    List<Candidate> recommendations(String userId, int limit) {
        return rankedCandidates(userId).stream()
                .limit(limit)
                .toList();
    }

    private List<Candidate> rankedCandidates(String userId) {
        List<FriendConnection> directFriends = traversalIndex.friendConnections(userId);
        Set<String> directFriendIds = new HashSet<>(directFriends.stream()
                .map(FriendConnection::userId)
                .toList());
        Set<String> directFollowedIds = new HashSet<>(repository.following(userId).stream()
                .map(SocialUserFollowRecord::followedUserId)
                .toList());
        Map<String, CandidateBuilder> candidates = new HashMap<>();

        for (FriendConnection directFriend : directFriends) {
            for (FriendConnection secondHop : traversalIndex.friendConnections(directFriend.userId())) {
                if (isRecommendationCandidate(userId, secondHop.userId(), directFriendIds, directFollowedIds)) {
                    candidates.computeIfAbsent(secondHop.userId(), CandidateBuilder::new)
                            .mutualFriendIds
                            .add(directFriend.userId());
                }
            }
        }

        addFriendFollowSignals(userId, directFriends, directFriendIds, directFollowedIds, candidates);
        addFollowerSignals(userId, directFriendIds, directFollowedIds, candidates);

        for (FamilyConnection family : traversalIndex.familyFor(userId)) {
            if (isRecommendationCandidate(userId, family.relativeId(), directFriendIds, directFollowedIds)) {
                candidates.computeIfAbsent(family.relativeId(), CandidateBuilder::new).familyLink = true;
            }
        }

        addSharedMembershipSignals(
                userId,
                directFriendIds,
                directFollowedIds,
                repository.groupMemberships(),
                candidates,
                true);
        addSharedMembershipSignals(
                userId,
                directFriendIds,
                directFollowedIds,
                repository.communityMemberships(),
                candidates,
                false);

        return candidates.values().stream()
                .filter(candidate -> candidate.score() > 0)
                .sorted(Comparator.comparingDouble(CandidateBuilder::score).reversed()
                        .thenComparing(candidate -> candidate.userId))
                .map(CandidateBuilder::toCandidate)
                .toList();
    }

    private void addSharedMembershipSignals(
            String userId,
            Set<String> directFriendIds,
            Set<String> directFollowedIds,
            List<MembershipRecord> memberships,
            Map<String, CandidateBuilder> candidates,
            boolean groupSignal) {
        Set<String> userTargets = traversalIndex.targetIdsFor(memberships, userId);
        for (MembershipRecord membership : memberships) {
            String candidateUserId = membership.memberId();
            if (!userTargets.contains(membership.targetId())
                    || !isRecommendationCandidate(userId, candidateUserId, directFriendIds, directFollowedIds)) {
                continue;
            }
            CandidateBuilder candidate = candidates.computeIfAbsent(candidateUserId, CandidateBuilder::new);
            if (groupSignal) {
                candidate.sharedGroupIds.add(membership.targetId());
            } else {
                candidate.sharedCommunityIds.add(membership.targetId());
            }
        }
    }

    private void addFriendFollowSignals(
            String userId,
            List<FriendConnection> directFriends,
            Set<String> directFriendIds,
            Set<String> directFollowedIds,
            Map<String, CandidateBuilder> candidates) {
        for (FriendConnection directFriend : directFriends) {
            for (SocialUserFollowRecord follow : repository.following(directFriend.userId())) {
                String candidateUserId = follow.followedUserId();
                if (isRecommendationCandidate(userId, candidateUserId, directFriendIds, directFollowedIds)) {
                    candidates.computeIfAbsent(candidateUserId, CandidateBuilder::new)
                            .followedByFriendIds
                            .add(directFriend.userId());
                }
            }
        }
    }

    private void addFollowerSignals(
            String userId,
            Set<String> directFriendIds,
            Set<String> directFollowedIds,
            Map<String, CandidateBuilder> candidates) {
        for (SocialUserFollowRecord follow : repository.followers(userId)) {
            String candidateUserId = follow.followerId();
            if (isRecommendationCandidate(userId, candidateUserId, directFriendIds, directFollowedIds)) {
                candidates.computeIfAbsent(candidateUserId, CandidateBuilder::new).followsViewer = true;
            }
        }
    }

    private boolean isRecommendationCandidate(
            String userId,
            String candidateUserId,
            Set<String> directFriendIds,
            Set<String> directFollowedIds) {
        return !candidateUserId.equals(userId)
                && !directFriendIds.contains(candidateUserId)
                && !directFollowedIds.contains(candidateUserId)
                && !traversalIndex.blockedEitherWay(userId, candidateUserId)
                && relationshipPolicy.pendingFriendRequestBetween(userId, candidateUserId) == null
                && !pendingUserFollowRequestBetween(userId, candidateUserId);
    }

    private boolean pendingUserFollowRequestBetween(String firstUserId, String secondUserId) {
        return pendingUserFollowRequest(firstUserId, secondUserId)
                || pendingUserFollowRequest(secondUserId, firstUserId);
    }

    private boolean pendingUserFollowRequest(String followerId, String followedUserId) {
        SocialUserFollowRequestRecord request = repository.userFollowRequest(followerId, followedUserId);
        return request != null && "pending".equals(request.status());
    }

    record Candidate(
            String userId,
            String reason,
            int mutualFriendCount,
            int followedByFriendCount,
            int sharedGroupCount,
            int sharedCommunityCount,
            boolean familyLink,
            boolean followsViewer,
            double score,
            List<String> mutualFriendIds,
            List<String> followedByFriendIds,
            List<String> sharedGroupIds,
            List<String> sharedCommunityIds) {
    }

    private static final class CandidateBuilder {
        private final String userId;
        private final Set<String> mutualFriendIds = new HashSet<>();
        private final Set<String> followedByFriendIds = new HashSet<>();
        private final Set<String> sharedGroupIds = new HashSet<>();
        private final Set<String> sharedCommunityIds = new HashSet<>();
        private boolean familyLink;
        private boolean followsViewer;

        private CandidateBuilder(String userId) {
            this.userId = userId;
        }

        private Candidate toCandidate() {
            List<String> sortedMutualFriendIds = sorted(mutualFriendIds);
            List<String> sortedFollowedByFriendIds = sorted(followedByFriendIds);
            List<String> sortedSharedGroupIds = sorted(sharedGroupIds);
            List<String> sortedSharedCommunityIds = sorted(sharedCommunityIds);
            return new Candidate(
                    userId,
                    reason(),
                    sortedMutualFriendIds.size(),
                    sortedFollowedByFriendIds.size(),
                    sortedSharedGroupIds.size(),
                    sortedSharedCommunityIds.size(),
                    familyLink,
                    followsViewer,
                    score(),
                    sortedMutualFriendIds,
                    sortedFollowedByFriendIds,
                    sortedSharedGroupIds,
                    sortedSharedCommunityIds);
        }

        private String reason() {
            if (familyLink) {
                return "family";
            }
            if (!mutualFriendIds.isEmpty()) {
                return "mutual_friends";
            }
            if (!followedByFriendIds.isEmpty()) {
                return "followed_by_friends";
            }
            if (followsViewer) {
                return "follows_you";
            }
            if (!sharedGroupIds.isEmpty()) {
                return "shared_group";
            }
            return "shared_community";
        }

        private double score() {
            return (mutualFriendIds.size() * 10.0)
                    + (followedByFriendIds.size() * 6.0)
                    + (sharedGroupIds.size() * 4.0)
                    + (sharedCommunityIds.size() * 3.0)
                    + (familyLink ? 12.0 : 0.0)
                    + (followsViewer ? 5.0 : 0.0);
        }

        private List<String> sorted(Set<String> values) {
            return values.stream().sorted().toList();
        }
    }
}
