package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.BlockRequest;
import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;

import java.util.Objects;

final class SocialRelationshipEndpointWriteModel {
    private final SocialRelationshipWriteModel writeModel;
    private final SocialRelationshipPresentationResolver presentationResolver;

    SocialRelationshipEndpointWriteModel(
            SocialRelationshipWriteModel writeModel,
            SocialRelationshipPresentationResolver presentationResolver) {
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.presentationResolver = Objects.requireNonNull(presentationResolver, "presentationResolver");
    }

    FriendRequestResponse createFriendRequest(FriendRequestCreateRequest request) {
        FriendRequestRecord created = writeModel.createFriendRequest(request);
        return presentationResolver.friendRequest(created, created.fromUserId());
    }

    FriendRequestResponse acceptRequest(String requestId, String actorUserId) {
        FriendRequestRecord accepted = writeModel.acceptFriendRequest(requestId, actorUserId);
        return presentationResolver.friendRequest(accepted, accepted.toUserId());
    }

    FriendRequestResponse declineRequest(String requestId, String actorUserId) {
        FriendRequestRecord declined = writeModel.declineFriendRequest(requestId, actorUserId);
        return presentationResolver.friendRequest(declined, declined.toUserId());
    }

    FriendSummary addCloseFriend(String userId, String friendId) {
        CloseFriendRecord closeFriend = writeModel.addCloseFriend(userId, friendId);
        return presentationResolver.friend(
                closeFriend.friendId(),
                closeFriend.createdAt(),
                true,
                closeFriend.ownerId());
    }

    void removeCloseFriend(String userId, String friendId) {
        writeModel.removeCloseFriend(userId, friendId);
    }

    SocialUserFollowResponse followUser(String followedUserId, SocialUserFollowRequest request) {
        return followResponse(writeModel.followUser(followedUserId, request));
    }

    void unfollowUser(String followedUserId, String followerId) {
        writeModel.unfollowUser(followedUserId, followerId);
    }

    SocialUserFollowResponse decideUserFollowRequest(
            String followedUserId,
            String followerId,
            SocialUserFollowDecisionRequest request) {
        return followResponse(writeModel.decideUserFollowRequest(followedUserId, followerId, request));
    }

    void removeFriend(String userId, String friendId) {
        writeModel.removeFriend(userId, friendId);
    }

    BlockResponse block(BlockRequest request) {
        return presentationResolver.block(writeModel.block(request));
    }

    void unblock(String userId, String blockedUserId) {
        writeModel.unblock(userId, blockedUserId);
    }

    SocialMuteResponse mute(SocialMuteRequest request) {
        return presentationResolver.mute(writeModel.mute(request));
    }

    void unmute(String userId, String targetType, String targetId) {
        writeModel.unmute(userId, targetType, targetId);
    }

    FamilyLinkResponse createFamilyLink(FamilyLinkCreateRequest request) {
        return presentationResolver.family(writeModel.createFamilyLink(request));
    }

    void removeFamilyLink(String userId, String relativeId) {
        writeModel.removeFamilyLink(userId, relativeId);
    }

    private SocialUserFollowResponse followResponse(SocialRelationshipWriteModel.SocialUserFollowWriteResult result) {
        if (result.follow() != null) {
            return presentationResolver.follow(result.follow(), result.viewerId());
        }
        return presentationResolver.followRequest(result.request(), result.viewerId());
    }
}
