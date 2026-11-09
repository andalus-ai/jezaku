package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

final class SocialRelationshipReadModel {
    private final SocialRelationshipGraphStore repository;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialChronologicalPaginationPlanner chronologicalPaginationPlanner;
    private final BiPredicate<String, String> blockedEitherWay;

    SocialRelationshipReadModel(
            SocialRelationshipGraphStore repository,
            SocialRelationshipPolicy relationshipPolicy,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            BiPredicate<String, String> blockedEitherWay) {
        this.repository = repository;
        this.relationshipPolicy = relationshipPolicy;
        this.chronologicalPaginationPlanner = chronologicalPaginationPlanner;
        this.blockedEitherWay = blockedEitherWay;
    }

    RelationshipPage<FriendRequestRecord> friendRequests(
            String userId,
            String direction,
            String status,
            int limit,
            String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<FriendRequestRecord>> candidates =
                repository.friendRequests().stream()
                        .filter(request -> relationshipPolicy.friendRequestMatchesDirection(
                                request,
                                userId,
                                direction))
                        .filter(request -> relationshipPolicy.friendRequestMatchesStatus(request, status))
                        .map(request -> candidate(request, request.createdAt(), request.id()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<FriendshipRecord> friends(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<FriendshipRecord>> candidates =
                repository.friendships().stream()
                        .filter(friendship -> relationshipPolicy.containsUser(friendship, userId))
                        .map(friendship -> candidate(
                                friendship,
                                friendship.createdAt(),
                                friendshipFriendId(friendship, userId)))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<CloseFriendRecord> closeFriends(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<CloseFriendRecord>> candidates =
                repository.closeFriends().stream()
                        .filter(closeFriend -> closeFriend.ownerId().equals(userId))
                        .map(closeFriend -> candidate(closeFriend, closeFriend.createdAt(), closeFriend.friendId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<SocialUserFollowRequestRecord> userFollowRequests(
            String userId,
            String direction,
            String status,
            int limit,
            String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialUserFollowRequestRecord>> candidates =
                repository.userFollowRequests().stream()
                        .filter(request -> relationshipPolicy.userFollowRequestMatchesDirection(
                                request,
                                userId,
                                direction))
                        .filter(request -> "all".equals(status) || request.status().equals(status))
                        .map(request -> candidate(request, request.updatedAt(), userFollowRequestCursorId(request)))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<SocialUserFollowRecord> followers(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialUserFollowRecord>> candidates =
                repository.followers(userId).stream()
                        .map(follow -> candidate(follow, follow.createdAt(), follow.followerId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<SocialUserFollowRecord> following(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialUserFollowRecord>> candidates =
                repository.following(userId).stream()
                        .map(follow -> candidate(follow, follow.createdAt(), follow.followedUserId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<BlockRecord> blocks(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<BlockRecord>> candidates =
                repository.blocks().stream()
                        .filter(block -> block.userId().equals(userId))
                        .map(block -> candidate(block, block.createdAt(), block.blockedUserId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<SocialMuteRecord> mutes(String userId, String targetType, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<SocialMuteRecord>> candidates =
                repository.mutesByUser(userId).stream()
                        .filter(mute -> "all".equals(targetType) || mute.targetType().equals(targetType))
                        .map(mute -> candidate(mute, mute.createdAt(), muteCursorId(mute)))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    RelationshipPage<FamilyLinkRecord> family(String userId, int limit, String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<FamilyLinkRecord>> candidates =
                repository.familyLinks().stream()
                        .filter(link -> link.firstUserId().equals(userId) || link.secondUserId().equals(userId))
                        .filter(link -> !blockedEitherWay.test(link.firstUserId(), link.secondUserId()))
                        .map(link -> candidate(link, link.createdAt(), familyCursorId(link, userId)))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    private <T> RelationshipPage<T> descending(
            int limit,
            String cursor,
            List<SocialChronologicalPaginationPlanner.Candidate<T>> candidates) {
        SocialChronologicalPaginationPlanner.Page<T> page =
                chronologicalPaginationPlanner.descending(limit, cursor, candidates);
        return new RelationshipPage<>(page.items(), page.hasMore(), page.nextCursor());
    }

    private <T> SocialChronologicalPaginationPlanner.Candidate<T> candidate(
            T item,
            Instant createdAt,
            String id) {
        return new SocialChronologicalPaginationPlanner.Candidate<>(item, createdAt, id);
    }

    private String friendshipFriendId(FriendshipRecord friendship, String userId) {
        return friendship.firstUserId().equals(userId) ? friendship.secondUserId() : friendship.firstUserId();
    }

    private String userFollowRequestCursorId(SocialUserFollowRequestRecord request) {
        return request.followerId() + "|" + request.followedUserId();
    }

    private String muteCursorId(SocialMuteRecord mute) {
        return mute.targetType() + "|" + mute.targetId();
    }

    private String familyCursorId(FamilyLinkRecord link, String userId) {
        return link.firstUserId().equals(userId) ? link.secondUserId() : link.firstUserId();
    }

    record RelationshipPage<T>(List<T> items, boolean hasMore, String nextCursor) {
    }
}
