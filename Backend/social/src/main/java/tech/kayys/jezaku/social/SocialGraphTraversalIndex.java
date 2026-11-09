package tech.kayys.jezaku.social;

import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

final class SocialGraphTraversalIndex {
    private final SocialGraphRepository repository;
    private final SocialRelationshipPolicy relationshipPolicy;

    SocialGraphTraversalIndex(SocialGraphRepository repository) {
        this(repository, new SocialRelationshipPolicy(repository));
    }

    SocialGraphTraversalIndex(
            SocialGraphRepository repository,
            SocialRelationshipPolicy relationshipPolicy) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
    }

    boolean blockedEitherWay(String firstUserId, String secondUserId) {
        return relationshipPolicy.blockedEitherWay(firstUserId, secondUserId);
    }

    List<FriendConnection> friendConnections(String userId) {
        return repository.friendships().stream()
                .filter(friendship -> relationshipPolicy.containsUser(friendship, userId))
                .map(friendship -> friendConnection(friendship, userId))
                .filter(connection -> !relationshipPolicy.blockedEitherWay(userId, connection.userId()))
                .sorted(Comparator.comparing(FriendConnection::userId))
                .toList();
    }

    Set<String> friendsOfFriends(String userId) {
        Set<String> directFriends = new HashSet<>(friendConnections(userId).stream()
                .map(FriendConnection::userId)
                .toList());
        Set<String> secondHop = new HashSet<>();
        for (String friendId : directFriends) {
            friendConnections(friendId).stream()
                    .map(FriendConnection::userId)
                    .filter(candidate -> !candidate.equals(userId))
                    .filter(candidate -> !directFriends.contains(candidate))
                    .filter(candidate -> !relationshipPolicy.blockedEitherWay(userId, candidate))
                    .forEach(secondHop::add);
        }
        return secondHop;
    }

    List<String> mutualFriendIds(String firstUserId, String secondUserId) {
        if (firstUserId.equals(secondUserId)) {
            return List.of();
        }
        Set<String> firstFriends = new HashSet<>(friendConnections(firstUserId).stream()
                .map(FriendConnection::userId)
                .toList());
        return friendConnections(secondUserId).stream()
                .map(FriendConnection::userId)
                .filter(firstFriends::contains)
                .filter(userId -> !relationshipPolicy.blockedEitherWay(firstUserId, userId))
                .filter(userId -> !relationshipPolicy.blockedEitherWay(secondUserId, userId))
                .sorted()
                .toList();
    }

    List<FamilyConnection> familyFor(String userId) {
        return repository.familyLinks().stream()
                .filter(link -> link.firstUserId().equals(userId) || link.secondUserId().equals(userId))
                .map(link -> new FamilyConnection(
                        link.firstUserId().equals(userId) ? link.secondUserId() : link.firstUserId(),
                        link.relationship(),
                        link.createdAt()))
                .filter(connection -> !relationshipPolicy.blockedEitherWay(userId, connection.relativeId()))
                .sorted(Comparator.comparing(FamilyConnection::relativeId))
                .toList();
    }

    FamilyConnection familyConnectionBetween(String firstUserId, String secondUserId) {
        return familyFor(firstUserId).stream()
                .filter(connection -> connection.relativeId().equals(secondUserId))
                .findFirst()
                .orElse(null);
    }

    List<MembershipRecord> membershipsFor(List<MembershipRecord> memberships, String userId) {
        return memberships.stream()
                .filter(membership -> membership.memberId().equals(userId))
                .sorted(Comparator.comparing(MembershipRecord::targetId))
                .toList();
    }

    Set<String> sharedMembershipUserIds(List<MembershipRecord> memberships, String userId) {
        Set<String> userTargets = targetIdsFor(memberships, userId);
        return new HashSet<>(memberships.stream()
                .filter(membership -> userTargets.contains(membership.targetId()))
                .map(MembershipRecord::memberId)
                .filter(memberId -> !memberId.equals(userId))
                .filter(memberId -> !relationshipPolicy.blockedEitherWay(userId, memberId))
                .toList());
    }

    List<String> sharedTargetIds(List<MembershipRecord> memberships, String firstUserId, String secondUserId) {
        if (firstUserId.equals(secondUserId)) {
            return List.of();
        }
        Set<String> firstTargets = targetIdsFor(memberships, firstUserId);
        return memberships.stream()
                .filter(membership -> membership.memberId().equals(secondUserId))
                .map(MembershipRecord::targetId)
                .filter(firstTargets::contains)
                .distinct()
                .sorted()
                .toList();
    }

    int memberCount(List<MembershipRecord> memberships, String targetId) {
        return (int) memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .count();
    }

    int blockedHiddenCount(String userId) {
        Set<String> hidden = new HashSet<>();
        repository.blocks().stream()
                .filter(block -> block.userId().equals(userId))
                .map(BlockRecord::blockedUserId)
                .forEach(hidden::add);
        repository.blocks().stream()
                .filter(block -> block.blockedUserId().equals(userId))
                .map(BlockRecord::userId)
                .forEach(hidden::add);
        return hidden.size();
    }

    private FriendConnection friendConnection(FriendshipRecord friendship, String userId) {
        String friendId = friendship.firstUserId().equals(userId)
                ? friendship.secondUserId()
                : friendship.firstUserId();
        return new FriendConnection(friendId, friendship.createdAt(), relationshipPolicy.closeFriend(userId, friendId));
    }

    Set<String> targetIdsFor(List<MembershipRecord> memberships, String userId) {
        return new HashSet<>(memberships.stream()
                .filter(membership -> membership.memberId().equals(userId))
                .map(MembershipRecord::targetId)
                .toList());
    }
}
