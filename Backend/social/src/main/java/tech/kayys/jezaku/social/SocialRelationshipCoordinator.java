package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.BlockListResponse;
import tech.kayys.jezaku.social.SocialDtos.BlockRequest;
import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkListResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;

import java.util.Objects;

/**
 * Coordinates relationship endpoint workflows for friends, follows, blocks, mutes, and family links.
 */
final class SocialRelationshipCoordinator {
    private static final int DEFAULT_FRIEND_REQUEST_LIST_LIMIT = 100;
    private static final int DEFAULT_FRIEND_LIST_LIMIT = 100;
    private static final int DEFAULT_FOLLOW_LIST_LIMIT = 100;
    private static final int DEFAULT_FOLLOW_REQUEST_LIST_LIMIT = 100;
    private static final int DEFAULT_BLOCK_LIST_LIMIT = 100;
    private static final int DEFAULT_MUTE_LIST_LIMIT = 100;
    private static final int DEFAULT_FAMILY_LINK_LIST_LIMIT = 100;

    private final SocialRelationshipEndpointReadModel readModel;
    private final SocialRelationshipEndpointWriteModel writeModel;

    SocialRelationshipCoordinator(
            SocialRelationshipGraphStore repository,
            SocialRelationshipPolicy relationshipPolicy,
            SocialUserProfileResolver profileResolver,
            SocialGraphEntityResolver entityResolver,
            SocialActivityPublisher activityPublisher,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            Limits limits) {
        SocialRelationshipGraphStore resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialRelationshipPolicy resolvedRelationshipPolicy =
                Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        SocialUserProfileResolver resolvedProfileResolver = Objects.requireNonNull(profileResolver, "profileResolver");
        SocialGraphEntityResolver resolvedEntityResolver = Objects.requireNonNull(entityResolver, "entityResolver");
        SocialActivityPublisher resolvedActivityPublisher =
                Objects.requireNonNull(activityPublisher, "activityPublisher");
        SocialChronologicalPaginationPlanner resolvedChronologicalPaginationPlanner =
                Objects.requireNonNull(chronologicalPaginationPlanner, "chronologicalPaginationPlanner");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        SocialRelationshipPresentationResolver presentationResolver = new SocialRelationshipPresentationResolver(
                resolvedRelationshipPolicy,
                resolvedProfileResolver::card);
        SocialRelationshipWriteModel relationshipWriteModel = new SocialRelationshipWriteModel(
                resolvedRepository,
                resolvedRelationshipPolicy,
                resolvedProfileResolver::profileFor,
                resolvedProfileResolver::userLabel,
                resolvedActivityPublisher::recordActivity,
                new SocialMuteTargetGuard(resolvedEntityResolver));
        this.writeModel = new SocialRelationshipEndpointWriteModel(relationshipWriteModel, presentationResolver);
        SocialRelationshipReadModel relationshipReadModel = new SocialRelationshipReadModel(
                resolvedRepository,
                resolvedRelationshipPolicy,
                resolvedChronologicalPaginationPlanner,
                resolvedRelationshipPolicy::blockedEitherWay);
        this.readModel = new SocialRelationshipEndpointReadModel(
                relationshipReadModel,
                presentationResolver,
                new SocialRelationshipEndpointReadModel.Limits(
                        resolvedLimits.friendRequestListLimit(),
                        resolvedLimits.friendListLimit(),
                        resolvedLimits.followListLimit(),
                        resolvedLimits.followRequestListLimit(),
                        resolvedLimits.blockListLimit(),
                        resolvedLimits.muteListLimit(),
                        resolvedLimits.familyLinkListLimit()));
    }

    FriendRequestResponse createFriendRequest(FriendRequestCreateRequest request) {
        return writeModel.createFriendRequest(request);
    }

    FriendRequestListResponse friendRequests(
            String userId,
            String direction,
            String status,
            Integer limit,
            String cursor) {
        return readModel.friendRequests(userId, direction, status, limit, cursor);
    }

    FriendRequestResponse acceptRequest(String requestId, String actorUserId) {
        return writeModel.acceptRequest(requestId, actorUserId);
    }

    FriendRequestResponse declineRequest(String requestId, String actorUserId) {
        return writeModel.declineRequest(requestId, actorUserId);
    }

    FriendListResponse friends(String userId, String viewerId, Integer limit, String cursor) {
        return readModel.friends(userId, viewerId, limit, cursor);
    }

    FriendListResponse closeFriends(String userId, String viewerId, Integer limit, String cursor) {
        return readModel.closeFriends(userId, viewerId, limit, cursor);
    }

    FriendSummary addCloseFriend(String userId, String friendId) {
        return writeModel.addCloseFriend(userId, friendId);
    }

    void removeCloseFriend(String userId, String friendId) {
        writeModel.removeCloseFriend(userId, friendId);
    }

    SocialUserFollowResponse followUser(String followedUserId, SocialUserFollowRequest request) {
        return writeModel.followUser(followedUserId, request);
    }

    void unfollowUser(String followedUserId, String followerId) {
        writeModel.unfollowUser(followedUserId, followerId);
    }

    SocialUserFollowRequestListResponse userFollowRequests(
            String userId,
            String direction,
            String status,
            Integer limit,
            String cursor) {
        return readModel.userFollowRequests(userId, direction, status, limit, cursor);
    }

    SocialUserFollowResponse decideUserFollowRequest(
            String followedUserId,
            String followerId,
            SocialUserFollowDecisionRequest request) {
        return writeModel.decideUserFollowRequest(followedUserId, followerId, request);
    }

    SocialUserFollowListResponse followers(String userId, String viewerId, Integer limit, String cursor) {
        return readModel.followers(userId, viewerId, limit, cursor);
    }

    SocialUserFollowListResponse following(String userId, String viewerId, Integer limit, String cursor) {
        return readModel.following(userId, viewerId, limit, cursor);
    }

    void removeFriend(String userId, String friendId) {
        writeModel.removeFriend(userId, friendId);
    }

    BlockResponse block(BlockRequest request) {
        return writeModel.block(request);
    }

    BlockListResponse blocks(String userId, Integer limit, String cursor) {
        return readModel.blocks(userId, limit, cursor);
    }

    void unblock(String userId, String blockedUserId) {
        writeModel.unblock(userId, blockedUserId);
    }

    SocialMuteResponse mute(SocialMuteRequest request) {
        return writeModel.mute(request);
    }

    SocialMuteListResponse mutes(String userId, String targetType, Integer limit, String cursor) {
        return readModel.mutes(userId, targetType, limit, cursor);
    }

    void unmute(String userId, String targetType, String targetId) {
        writeModel.unmute(userId, targetType, targetId);
    }

    FamilyLinkResponse createFamilyLink(FamilyLinkCreateRequest request) {
        return writeModel.createFamilyLink(request);
    }

    FamilyLinkListResponse family(String userId, Integer limit, String cursor) {
        return readModel.family(userId, limit, cursor);
    }

    void removeFamilyLink(String userId, String relativeId) {
        writeModel.removeFamilyLink(userId, relativeId);
    }

    static Limits defaultLimits() {
        return new Limits(
                DEFAULT_FRIEND_REQUEST_LIST_LIMIT,
                DEFAULT_FRIEND_LIST_LIMIT,
                DEFAULT_FOLLOW_LIST_LIMIT,
                DEFAULT_FOLLOW_REQUEST_LIST_LIMIT,
                DEFAULT_BLOCK_LIST_LIMIT,
                DEFAULT_MUTE_LIST_LIMIT,
                DEFAULT_FAMILY_LINK_LIST_LIMIT);
    }

    /**
     * Defines endpoint list limits for relationship workflows.
     */
    record Limits(
            int friendRequestListLimit,
            int friendListLimit,
            int followListLimit,
            int followRequestListLimit,
            int blockListLimit,
            int muteListLimit,
            int familyLinkListLimit) {
    }
}
