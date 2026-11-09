package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.BlockListResponse;
import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkListResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialRelationshipEndpointReadModel {
    private static final Set<String> DIRECTIONS = Set.of("incoming", "outgoing", "all");
    private static final Set<String> FRIEND_REQUEST_STATUSES = Set.of("all", "pending", "accepted", "declined");
    private static final Set<String> MUTE_TARGET_TYPES = Set.of("all", "user", "group", "community");
    private static final Set<String> USER_FOLLOW_REQUEST_STATUSES = Set.of("pending", "accepted", "rejected");

    private final SocialRelationshipReadModel readModel;
    private final SocialRelationshipPresentationResolver presentationResolver;
    private final Limits limits;

    SocialRelationshipEndpointReadModel(
            SocialRelationshipReadModel readModel,
            SocialRelationshipPresentationResolver presentationResolver,
            Limits limits) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.presentationResolver = Objects.requireNonNull(presentationResolver, "presentationResolver");
        this.limits = Objects.requireNonNull(limits, "limits");
    }

    FriendRequestListResponse friendRequests(
            String userId,
            String direction,
            String status,
            Integer limit,
            String cursor) {
        String user = requireText(userId, "userId");
        String normalizedDirection = relationshipDirection(direction);
        String normalizedStatus = friendRequestStatus(status);
        int normalizedLimit = normalizeBoundedInt(
                limit,
                50,
                1,
                limits.friendRequestList(),
                "limit");
        SocialRelationshipReadModel.RelationshipPage<FriendRequestRecord> page =
                readModel.friendRequests(user, normalizedDirection, normalizedStatus, normalizedLimit, cursor);
        List<FriendRequestResponse> requests = page.items().stream()
                .map(request -> presentationResolver.friendRequest(request, user))
                .toList();
        return new FriendRequestListResponse(
                user,
                normalizedDirection,
                normalizedStatus,
                requests.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                requests);
    }

    FriendListResponse friends(String userId, String viewerId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        String viewer = optionalTrim(viewerId, user);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.friendList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<FriendshipRecord> page =
                readModel.friends(user, normalizedLimit, cursor);
        List<FriendSummary> friends = page.items().stream()
                .map(friendship -> presentationResolver.friend(friendship, user, viewer))
                .toList();
        return new FriendListResponse(
                user,
                friends.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                friends);
    }

    FriendListResponse closeFriends(String userId, String viewerId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        String viewer = optionalTrim(viewerId, user);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.friendList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<CloseFriendRecord> page =
                readModel.closeFriends(user, normalizedLimit, cursor);
        List<FriendSummary> friends = page.items().stream()
                .map(closeFriend -> presentationResolver.friend(
                        closeFriend.friendId(),
                        closeFriend.createdAt(),
                        true,
                        viewer))
                .toList();
        return new FriendListResponse(
                user,
                friends.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                friends);
    }

    SocialUserFollowRequestListResponse userFollowRequests(
            String userId,
            String direction,
            String status,
            Integer limit,
            String cursor) {
        String user = requireText(userId, "userId");
        String normalizedDirection = relationshipDirection(direction);
        String normalizedStatus = userFollowRequestStatus(status);
        int normalizedLimit = normalizeBoundedInt(
                limit,
                50,
                1,
                limits.followRequestList(),
                "limit");
        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRequestRecord> page =
                readModel.userFollowRequests(user, normalizedDirection, normalizedStatus, normalizedLimit, cursor);
        List<SocialUserFollowResponse> requests = page.items().stream()
                .map(request -> presentationResolver.followRequest(request, user))
                .toList();
        return new SocialUserFollowRequestListResponse(
                user,
                normalizedDirection,
                normalizedStatus,
                requests.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                requests);
    }

    SocialUserFollowListResponse followers(String userId, String viewerId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        String viewer = optionalTrim(viewerId, user);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.followList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRecord> page =
                readModel.followers(user, normalizedLimit, cursor);
        List<SocialUserFollowResponse> follows = page.items().stream()
                .map(follow -> presentationResolver.follow(follow, viewer))
                .toList();
        return new SocialUserFollowListResponse(
                user,
                "followers",
                follows.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                follows);
    }

    SocialUserFollowListResponse following(String userId, String viewerId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        String viewer = optionalTrim(viewerId, user);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.followList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRecord> page =
                readModel.following(user, normalizedLimit, cursor);
        List<SocialUserFollowResponse> follows = page.items().stream()
                .map(follow -> presentationResolver.follow(follow, viewer))
                .toList();
        return new SocialUserFollowListResponse(
                user,
                "following",
                follows.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                follows);
    }

    BlockListResponse blocks(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.blockList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<BlockRecord> page =
                readModel.blocks(user, normalizedLimit, cursor);
        List<BlockResponse> blocks = page.items().stream()
                .map(presentationResolver::block)
                .toList();
        return new BlockListResponse(
                user,
                blocks.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                blocks);
    }

    SocialMuteListResponse mutes(String userId, String targetType, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        String normalizedTargetType = muteTargetType(targetType);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.muteList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<SocialMuteRecord> page =
                readModel.mutes(user, normalizedTargetType, normalizedLimit, cursor);
        List<SocialMuteResponse> mutes = page.items().stream()
                .map(presentationResolver::mute)
                .toList();
        return new SocialMuteListResponse(
                user,
                normalizedTargetType,
                mutes.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                mutes);
    }

    FamilyLinkListResponse family(String userId, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, limits.familyList(), "limit");
        SocialRelationshipReadModel.RelationshipPage<FamilyLinkRecord> page =
                readModel.family(user, normalizedLimit, cursor);
        List<FamilyLinkResponse> links = page.items().stream()
                .map(presentationResolver::family)
                .toList();
        return new FamilyLinkListResponse(
                user,
                links.size(),
                normalizedLimit,
                page.hasMore(),
                page.nextCursor(),
                links);
    }

    private String relationshipDirection(String direction) {
        return optionalChoice(
                direction,
                "incoming",
                DIRECTIONS,
                "direction",
                "direction must be incoming, outgoing, or all");
    }

    private String friendRequestStatus(String status) {
        return optionalChoice(
                status,
                "all",
                FRIEND_REQUEST_STATUSES,
                "status",
                "status must be all, pending, accepted, or declined");
    }

    private String muteTargetType(String targetType) {
        return optionalChoice(
                targetType,
                "all",
                MUTE_TARGET_TYPES,
                "targetType",
                "targetType must be all, user, group, or community");
    }

    private String userFollowRequestStatus(String status) {
        Set<String> statuses = new HashSet<>(USER_FOLLOW_REQUEST_STATUSES);
        statuses.add("all");
        return optionalChoice(
                status,
                "pending",
                statuses,
                "status",
                "status must be pending, accepted, rejected, or all");
    }

    record Limits(
            int friendRequestList,
            int friendList,
            int followList,
            int followRequestList,
            int blockList,
            int muteList,
            int familyList) {
    }
}
