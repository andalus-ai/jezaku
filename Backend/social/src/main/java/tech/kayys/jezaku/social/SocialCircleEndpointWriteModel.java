package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipInviteCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipJoinRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipRoleUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.util.Objects;

final class SocialCircleEndpointWriteModel {
    private final SocialCircleWriteModel writeModel;
    private final SocialCircleContentModerationWriteModel moderationWriteModel;
    private final SocialCirclePresentationResolver presentationResolver;

    SocialCircleEndpointWriteModel(
            SocialCircleWriteModel writeModel,
            SocialCircleContentModerationWriteModel moderationWriteModel,
            SocialCirclePresentationResolver presentationResolver) {
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.moderationWriteModel = Objects.requireNonNull(moderationWriteModel, "moderationWriteModel");
        this.presentationResolver = Objects.requireNonNull(presentationResolver, "presentationResolver");
    }

    SocialGroupResponse createGroup(SocialGroupCreateRequest request) {
        return presentationResolver.group(writeModel.createGroup(request), "");
    }

    MembershipResponse addGroupMember(String groupId, MembershipCreateRequest request, String actorUserId) {
        return addMember("group", groupId, request, actorUserId);
    }

    MembershipResponse joinGroup(String groupId, MembershipJoinRequest request) {
        return join("group", groupId, request);
    }

    void leaveGroup(String groupId, String userId) {
        leave("group", groupId, userId);
    }

    CircleMembershipRequestResponse requestGroupJoin(
            String groupId,
            CircleMembershipRequestCreateRequest request) {
        return requestJoin("group", groupId, request);
    }

    CircleMembershipRequestResponse decideGroupJoinRequest(
            String groupId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return decideJoinRequest("group", groupId, requestId, request);
    }

    CircleMembershipRequestResponse inviteGroupMember(
            String groupId,
            CircleMembershipInviteCreateRequest request) {
        return inviteMember("group", groupId, request);
    }

    CircleMembershipRequestResponse decideGroupInvite(
            String groupId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return decideInvite("group", groupId, requestId, request);
    }

    void removeGroupMember(String groupId, String memberId, String actorUserId) {
        removeMember("group", groupId, memberId, actorUserId);
    }

    MembershipResponse updateGroupMemberRole(
            String groupId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return updateMemberRole("group", groupId, memberId, request, actorUserId);
    }

    CircleOwnershipTransferResponse transferGroupOwnership(
            String groupId,
            CircleOwnershipTransferRequest request) {
        return transferOwnership("group", groupId, request);
    }

    CircleContentModerationResponse moderateGroupContent(
            String groupId,
            String contentId,
            CircleContentModerationRequest request) {
        return moderate("group", groupId, contentId, request);
    }

    SocialCommunityResponse createCommunity(SocialCommunityCreateRequest request) {
        return presentationResolver.community(writeModel.createCommunity(request), "");
    }

    MembershipResponse addCommunityMember(
            String communityId,
            MembershipCreateRequest request,
            String actorUserId) {
        return addMember("community", communityId, request, actorUserId);
    }

    MembershipResponse joinCommunity(String communityId, MembershipJoinRequest request) {
        return join("community", communityId, request);
    }

    void leaveCommunity(String communityId, String userId) {
        leave("community", communityId, userId);
    }

    CircleMembershipRequestResponse requestCommunityJoin(
            String communityId,
            CircleMembershipRequestCreateRequest request) {
        return requestJoin("community", communityId, request);
    }

    CircleMembershipRequestResponse decideCommunityJoinRequest(
            String communityId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return decideJoinRequest("community", communityId, requestId, request);
    }

    CircleMembershipRequestResponse inviteCommunityMember(
            String communityId,
            CircleMembershipInviteCreateRequest request) {
        return inviteMember("community", communityId, request);
    }

    CircleMembershipRequestResponse decideCommunityInvite(
            String communityId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return decideInvite("community", communityId, requestId, request);
    }

    void removeCommunityMember(String communityId, String memberId, String actorUserId) {
        removeMember("community", communityId, memberId, actorUserId);
    }

    MembershipResponse updateCommunityMemberRole(
            String communityId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return updateMemberRole("community", communityId, memberId, request, actorUserId);
    }

    CircleOwnershipTransferResponse transferCommunityOwnership(
            String communityId,
            CircleOwnershipTransferRequest request) {
        return transferOwnership("community", communityId, request);
    }

    CircleContentModerationResponse moderateCommunityContent(
            String communityId,
            String contentId,
            CircleContentModerationRequest request) {
        return moderate("community", communityId, contentId, request);
    }

    private MembershipResponse addMember(
            String targetType,
            String targetId,
            MembershipCreateRequest request,
            String actorUserId) {
        return presentationResolver.membership(
                writeModel.addMember(targetType, targetId, request, actorUserId),
                targetType);
    }

    private MembershipResponse join(String targetType, String targetId, MembershipJoinRequest request) {
        return presentationResolver.membership(writeModel.join(targetType, targetId, request), targetType);
    }

    private void leave(String targetType, String targetId, String userId) {
        writeModel.leave(targetType, targetId, userId);
    }

    private CircleMembershipRequestResponse requestJoin(
            String targetType,
            String targetId,
            CircleMembershipRequestCreateRequest request) {
        return presentationResolver.membershipRequest(writeModel.requestJoin(targetType, targetId, request));
    }

    private CircleMembershipRequestResponse decideJoinRequest(
            String targetType,
            String targetId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return presentationResolver.membershipRequest(
                writeModel.decideJoinRequest(targetType, targetId, requestId, request));
    }

    private CircleMembershipRequestResponse inviteMember(
            String targetType,
            String targetId,
            CircleMembershipInviteCreateRequest request) {
        return presentationResolver.membershipRequest(writeModel.inviteMember(targetType, targetId, request));
    }

    private CircleMembershipRequestResponse decideInvite(
            String targetType,
            String targetId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return presentationResolver.membershipRequest(writeModel.decideInvite(targetType, targetId, requestId, request));
    }

    private void removeMember(String targetType, String targetId, String memberId, String actorUserId) {
        writeModel.removeMember(targetType, targetId, memberId, actorUserId);
    }

    private MembershipResponse updateMemberRole(
            String targetType,
            String targetId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return presentationResolver.membership(
                writeModel.updateMemberRole(targetType, targetId, memberId, request, actorUserId),
                targetType);
    }

    private CircleOwnershipTransferResponse transferOwnership(
            String targetType,
            String targetId,
            CircleOwnershipTransferRequest request) {
        return presentationResolver.ownershipTransfer(writeModel.transferOwnership(targetType, targetId, request));
    }

    private CircleContentModerationResponse moderate(
            String targetType,
            String targetId,
            String contentId,
            CircleContentModerationRequest request) {
        return presentationResolver.contentModeration(
                moderationWriteModel.moderate(targetType, targetId, contentId, request));
    }
}
