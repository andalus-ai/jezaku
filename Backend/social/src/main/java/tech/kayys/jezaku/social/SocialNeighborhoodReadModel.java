package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodBucket;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodCircle;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodConnector;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;

final class SocialNeighborhoodReadModel {
    private final SocialGraphRepository repository;
    private final SocialGraphTraversalIndex traversalIndex;
    private final Function<String, String> userLabel;

    SocialNeighborhoodReadModel(SocialGraphRepository repository, Function<String, String> userLabel) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.traversalIndex = new SocialGraphTraversalIndex(this.repository);
        this.userLabel = Objects.requireNonNull(userLabel, "userLabel");
    }

    SocialNeighborhoodSummaryResponse summary(String userId, int maxDepth, int limit) {
        List<FriendConnection> directFriends = traversalIndex.friendConnections(userId);
        Set<String> directFriendIds = new HashSet<>(directFriends.stream()
                .map(FriendConnection::userId)
                .toList());
        Set<String> closeFriendIds = new HashSet<>(directFriends.stream()
                .filter(FriendConnection::closeFriend)
                .map(FriendConnection::userId)
                .toList());
        Set<String> familyIds = new HashSet<>(traversalIndex.familyFor(userId).stream()
                .map(FamilyConnection::relativeId)
                .toList());
        Set<String> friendOfFriendIds = maxDepth >= 2 ? traversalIndex.friendsOfFriends(userId) : Set.of();
        Set<String> sharedGroupUserIds = maxDepth >= 2
                ? traversalIndex.sharedMembershipUserIds(repository.groupMemberships(), userId)
                : Set.of();
        Set<String> sharedCommunityUserIds = maxDepth >= 2
                ? traversalIndex.sharedMembershipUserIds(repository.communityMemberships(), userId)
                : Set.of();

        Set<String> sharedCircleUserIds = new HashSet<>(sharedGroupUserIds);
        sharedCircleUserIds.addAll(sharedCommunityUserIds);
        Set<String> visibleUserIds = new HashSet<>(directFriendIds);
        visibleUserIds.addAll(familyIds);
        visibleUserIds.addAll(friendOfFriendIds);
        visibleUserIds.addAll(sharedCircleUserIds);
        visibleUserIds.removeIf(candidate -> traversalIndex.blockedEitherWay(userId, candidate));

        return new SocialNeighborhoodSummaryResponse(
                userId,
                maxDepth,
                visibleUserIds.size(),
                directFriends.size(),
                closeFriendIds.size(),
                familyIds.size(),
                friendOfFriendIds.size(),
                sharedCircleUserIds.size(),
                traversalIndex.blockedHiddenCount(userId),
                List.of(
                        neighborhoodBucket("close_friend", closeFriendIds),
                        neighborhoodBucket("friend", nonCloseFriendIds(directFriendIds, closeFriendIds)),
                        neighborhoodBucket("family", familyIds),
                        neighborhoodBucket("friend_of_friend", friendOfFriendIds),
                        neighborhoodBucket("shared_group", sharedGroupUserIds),
                        neighborhoodBucket("shared_community", sharedCommunityUserIds)),
                topNeighborhoodConnectors(userId, directFriends, directFriendIds, limit),
                neighborhoodCircles(userId));
    }

    private List<SocialNeighborhoodConnector> topNeighborhoodConnectors(
            String userId,
            List<FriendConnection> directFriends,
            Set<String> directFriendIds,
            int limit) {
        return directFriends.stream()
                .map(friend -> neighborhoodConnector(userId, friend, directFriendIds))
                .sorted(Comparator.comparingDouble(SocialNeighborhoodConnector::score).reversed()
                        .thenComparing(SocialNeighborhoodConnector::userId))
                .limit(limit)
                .toList();
    }

    private SocialNeighborhoodConnector neighborhoodConnector(
            String userId,
            FriendConnection friend,
            Set<String> directFriendIds) {
        int introducedUserCount = (int) traversalIndex.friendConnections(friend.userId()).stream()
                .map(FriendConnection::userId)
                .filter(candidate -> !candidate.equals(userId))
                .filter(candidate -> !directFriendIds.contains(candidate))
                .filter(candidate -> !traversalIndex.blockedEitherWay(userId, candidate))
                .count();
        int sharedGroupCount = traversalIndex.sharedTargetIds(
                repository.groupMemberships(),
                userId,
                friend.userId()).size();
        int sharedCommunityCount = traversalIndex.sharedTargetIds(
                repository.communityMemberships(),
                userId,
                friend.userId()).size();
        double score = (friend.closeFriend() ? 12.0 : 6.0)
                + (introducedUserCount * 6.0)
                + (sharedGroupCount * 4.0)
                + (sharedCommunityCount * 3.0);
        return new SocialNeighborhoodConnector(
                friend.userId(),
                userLabel.apply(friend.userId()),
                friend.closeFriend() ? "close_friend" : "friend",
                introducedUserCount,
                sharedGroupCount,
                sharedCommunityCount,
                score);
    }

    private List<SocialNeighborhoodCircle> neighborhoodCircles(String userId) {
        List<SocialNeighborhoodCircle> circles = new ArrayList<>();
        for (MembershipRecord membership : traversalIndex.membershipsFor(repository.groupMemberships(), userId)) {
            SocialGroupRecord group = repository.group(membership.targetId());
            circles.add(new SocialNeighborhoodCircle(
                    membership.targetId(),
                    "group",
                    group == null ? membership.targetId() : group.name(),
                    membership.role(),
                    traversalIndex.memberCount(repository.groupMemberships(), membership.targetId())));
        }
        for (MembershipRecord membership : traversalIndex.membershipsFor(repository.communityMemberships(), userId)) {
            SocialCommunityRecord community = repository.community(membership.targetId());
            circles.add(new SocialNeighborhoodCircle(
                    membership.targetId(),
                    "community",
                    community == null ? membership.targetId() : community.name(),
                    membership.role(),
                    traversalIndex.memberCount(repository.communityMemberships(), membership.targetId())));
        }
        return circles.stream()
                .sorted(Comparator.comparing(SocialNeighborhoodCircle::targetType)
                        .thenComparing(SocialNeighborhoodCircle::targetId))
                .toList();
    }

    private SocialNeighborhoodBucket neighborhoodBucket(String relation, Set<String> userIds) {
        List<String> sortedUserIds = userIds.stream().sorted().toList();
        return new SocialNeighborhoodBucket(relation, sortedUserIds.size(), sortedUserIds);
    }

    private Set<String> nonCloseFriendIds(Set<String> directFriendIds, Set<String> closeFriendIds) {
        Set<String> friendIds = new HashSet<>(directFriendIds);
        friendIds.removeAll(closeFriendIds);
        return friendIds;
    }
}
