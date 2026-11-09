package tech.kayys.jezaku.social;

import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;

import java.util.Objects;

final class SocialRelationshipPolicy {
    private final SocialRelationshipGraphStore repository;

    SocialRelationshipPolicy(SocialRelationshipGraphStore repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    void ensureNotBlocked(String firstUserId, String secondUserId) {
        if (blockedEitherWay(firstUserId, secondUserId)) {
            throw conflict("Users cannot interact because one side has blocked the other");
        }
    }

    boolean blockedEitherWay(String firstUserId, String secondUserId) {
        return repository.blocks().stream()
                .anyMatch(block -> (block.userId().equals(firstUserId) && block.blockedUserId().equals(secondUserId))
                        || (block.userId().equals(secondUserId) && block.blockedUserId().equals(firstUserId)));
    }

    boolean friends(String firstUserId, String secondUserId) {
        return repository.friendships().stream()
                .anyMatch(friendship -> samePair(
                        friendship.firstUserId(),
                        friendship.secondUserId(),
                        firstUserId,
                        secondUserId));
    }

    boolean closeFriend(String ownerId, String friendId) {
        return repository.closeFriends().stream()
                .anyMatch(closeFriend -> closeFriend.ownerId().equals(ownerId)
                        && closeFriend.friendId().equals(friendId));
    }

    boolean containsUser(FriendshipRecord friendship, String userId) {
        return friendship.firstUserId().equals(userId) || friendship.secondUserId().equals(userId);
    }

    FriendRequestRecord pendingFriendRequestBetween(String firstUserId, String secondUserId) {
        return repository.friendRequests().stream()
                .filter(request -> "pending".equals(request.status()))
                .filter(request -> samePair(request.fromUserId(), request.toUserId(), firstUserId, secondUserId))
                .findFirst()
                .orElse(null);
    }

    int pendingFriendRequestsTo(String userId) {
        return (int) repository.friendRequests().stream()
                .filter(request -> "pending".equals(request.status()))
                .filter(request -> request.toUserId().equals(userId))
                .count();
    }

    int pendingFriendRequestsFrom(String userId) {
        return (int) repository.friendRequests().stream()
                .filter(request -> "pending".equals(request.status()))
                .filter(request -> request.fromUserId().equals(userId))
                .count();
    }

    boolean friendRequestMatchesDirection(FriendRequestRecord request, String userId, String direction) {
        return switch (direction) {
            case "incoming" -> request.toUserId().equals(userId);
            case "outgoing" -> request.fromUserId().equals(userId);
            default -> request.fromUserId().equals(userId) || request.toUserId().equals(userId);
        };
    }

    boolean friendRequestMatchesStatus(FriendRequestRecord request, String status) {
        return "all".equals(status) || request.status().equals(status);
    }

    boolean userFollowRequestMatchesDirection(
            SocialUserFollowRequestRecord request,
            String userId,
            String direction) {
        return switch (direction) {
            case "incoming" -> request.followedUserId().equals(userId);
            case "outgoing" -> request.followerId().equals(userId);
            default -> request.followerId().equals(userId) || request.followedUserId().equals(userId);
        };
    }

    boolean followRequiresApproval(
            String followerId,
            String followedUserId,
            SocialUserProfileRecord followedProfile) {
        return "private".equals(followedProfile.profileVisibility())
                && !friends(followerId, followedUserId);
    }

    void removeRelationshipState(String firstUserId, String secondUserId) {
        repository.removeFriendship(firstUserId, secondUserId);
        repository.removeCloseFriend(firstUserId, secondUserId);
        repository.removeCloseFriend(secondUserId, firstUserId);
        repository.removeUserFollow(firstUserId, secondUserId);
        repository.removeUserFollow(secondUserId, firstUserId);
        repository.removeUserFollowRequest(firstUserId, secondUserId);
        repository.removeUserFollowRequest(secondUserId, firstUserId);
        repository.friendRequests().stream()
                .filter(request -> "pending".equals(request.status()))
                .filter(request -> samePair(request.fromUserId(), request.toUserId(), firstUserId, secondUserId))
                .map(FriendRequestRecord::id)
                .toList()
                .forEach(repository::removeFriendRequest);
    }

    boolean samePair(String a, String b, String c, String d) {
        return (a.equals(c) && b.equals(d)) || (a.equals(d) && b.equals(c));
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }
}
