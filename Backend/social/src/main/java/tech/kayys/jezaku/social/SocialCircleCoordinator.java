package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipInviteCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipJoinRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipListResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipRoleUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCircleContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.util.Objects;

/**
 * Coordinates group and community endpoint workflows, membership operations, and circle moderation.
 */
final class SocialCircleCoordinator {
    private static final int DEFAULT_DIRECTORY_LIMIT = 100;
    private static final int DEFAULT_MEMBERSHIP_LIMIT = 100;
    private static final int DEFAULT_CONTENT_LIMIT = 100;
    private static final int DEFAULT_REQUEST_LIMIT = 100;
    private static final int DEFAULT_MODERATION_LIMIT = 100;

    private final SocialCircleEndpointReadModel readModel;
    private final SocialCircleEndpointWriteModel writeModel;

    SocialCircleCoordinator(
            SocialGraphRepository repository,
            SocialCircleMembershipPolicy membershipPolicy,
            SocialRelationshipPolicy relationshipPolicy,
            SocialContentAccessResolver contentAccessResolver,
            SocialActivityPublisher activityPublisher,
            SocialPresentationGateway presentationGateway,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialCircleMembershipPolicy resolvedMembershipPolicy =
                Objects.requireNonNull(membershipPolicy, "membershipPolicy");
        SocialRelationshipPolicy resolvedRelationshipPolicy =
                Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        SocialContentAccessResolver resolvedContentAccessResolver =
                Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        SocialActivityPublisher resolvedActivityPublisher =
                Objects.requireNonNull(activityPublisher, "activityPublisher");
        SocialPresentationGateway resolvedPresentationGateway =
                Objects.requireNonNull(presentationGateway, "presentationGateway");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        SocialCirclePresentationResolver presentationResolver =
                new SocialCirclePresentationResolver(resolvedRepository, resolvedMembershipPolicy);
        SocialCircleWriteModel circleWriteModel = new SocialCircleWriteModel(
                resolvedRepository,
                resolvedMembershipPolicy,
                resolvedRelationshipPolicy,
                resolvedActivityPublisher::recordActivity);
        SocialCircleContentModerationWriteModel circleContentModerationWriteModel =
                new SocialCircleContentModerationWriteModel(
                        resolvedRepository,
                        resolvedMembershipPolicy,
                        resolvedActivityPublisher::recordActivity);
        this.writeModel = new SocialCircleEndpointWriteModel(
                circleWriteModel,
                circleContentModerationWriteModel,
                presentationResolver);

        SocialCircleReadModel circleReadModel = new SocialCircleReadModel(
                resolvedRepository,
                new SocialCircleDirectoryPaginationPlanner(),
                new SocialMembershipPaginationPlanner(),
                new SocialContentPaginationPlanner(),
                resolvedMembershipPolicy,
                resolvedContentAccessResolver::audienceVisibleAndNotHidden);
        SocialCircleWorkflowReadModel circleWorkflowReadModel = new SocialCircleWorkflowReadModel(
                resolvedRepository,
                new SocialChronologicalPaginationPlanner(),
                resolvedMembershipPolicy);
        this.readModel = new SocialCircleEndpointReadModel(
                resolvedRepository,
                circleReadModel,
                circleWorkflowReadModel,
                resolvedMembershipPolicy,
                presentationResolver,
                resolvedPresentationGateway::content,
                new SocialCircleEndpointReadModel.Limits(
                        resolvedLimits.directoryLimit(),
                        resolvedLimits.membershipLimit(),
                        resolvedLimits.contentLimit(),
                        resolvedLimits.requestLimit(),
                        resolvedLimits.moderationLimit()));
    }

    SocialGroupResponse createGroup(SocialGroupCreateRequest request) {
        return writeModel.createGroup(request);
    }

    SocialGroupListResponse groups(Integer limit, String cursor, String query, String visibility, String viewerId) {
        return readModel.groups(limit, cursor, query, visibility, viewerId);
    }

    SocialGroupResponse group(String groupId) {
        return readModel.group(groupId);
    }

    MembershipResponse addGroupMember(String groupId, MembershipCreateRequest request, String actorUserId) {
        return writeModel.addGroupMember(groupId, request, actorUserId);
    }

    MembershipListResponse groupMembers(String groupId, Integer limit, String cursor) {
        return readModel.groupMembers(groupId, limit, cursor);
    }

    MembershipListResponse userGroups(String userId, Integer limit, String cursor) {
        return readModel.userGroups(userId, limit, cursor);
    }

    MembershipResponse joinGroup(String groupId, MembershipJoinRequest request) {
        return writeModel.joinGroup(groupId, request);
    }

    void leaveGroup(String groupId, String userId) {
        writeModel.leaveGroup(groupId, userId);
    }

    CircleMembershipRequestResponse requestGroupJoin(
            String groupId,
            CircleMembershipRequestCreateRequest request) {
        return writeModel.requestGroupJoin(groupId, request);
    }

    CircleMembershipRequestListResponse groupJoinRequests(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.groupJoinRequests(groupId, actorUserId, status, limit, cursor);
    }

    CircleMembershipRequestResponse decideGroupJoinRequest(
            String groupId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return writeModel.decideGroupJoinRequest(groupId, requestId, request);
    }

    CircleMembershipRequestResponse inviteGroupMember(
            String groupId,
            CircleMembershipInviteCreateRequest request) {
        return writeModel.inviteGroupMember(groupId, request);
    }

    CircleMembershipRequestListResponse groupInvites(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.groupInvites(groupId, actorUserId, status, limit, cursor);
    }

    CircleMembershipRequestResponse decideGroupInvite(
            String groupId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return writeModel.decideGroupInvite(groupId, requestId, request);
    }

    void removeGroupMember(String groupId, String memberId, String actorUserId) {
        writeModel.removeGroupMember(groupId, memberId, actorUserId);
    }

    MembershipResponse updateGroupMemberRole(
            String groupId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return writeModel.updateGroupMemberRole(groupId, memberId, request, actorUserId);
    }

    CircleOwnershipTransferResponse transferGroupOwnership(
            String groupId,
            CircleOwnershipTransferRequest request) {
        return writeModel.transferGroupOwnership(groupId, request);
    }

    SocialCircleContentListResponse groupContent(String groupId, String viewerId, Integer limit, String cursor) {
        return readModel.groupContent(groupId, viewerId, limit, cursor);
    }

    CircleContentModerationResponse moderateGroupContent(
            String groupId,
            String contentId,
            CircleContentModerationRequest request) {
        return writeModel.moderateGroupContent(groupId, contentId, request);
    }

    CircleContentModerationListResponse groupContentModeration(
            String groupId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.groupContentModeration(groupId, actorUserId, status, limit, cursor);
    }

    SocialCommunityResponse createCommunity(SocialCommunityCreateRequest request) {
        return writeModel.createCommunity(request);
    }

    SocialCommunityListResponse communities(
            Integer limit,
            String cursor,
            String query,
            String visibility,
            String viewerId) {
        return readModel.communities(limit, cursor, query, visibility, viewerId);
    }

    SocialCommunityResponse community(String communityId) {
        return readModel.community(communityId);
    }

    MembershipResponse addCommunityMember(
            String communityId,
            MembershipCreateRequest request,
            String actorUserId) {
        return writeModel.addCommunityMember(communityId, request, actorUserId);
    }

    MembershipListResponse communityMembers(String communityId, Integer limit, String cursor) {
        return readModel.communityMembers(communityId, limit, cursor);
    }

    MembershipListResponse userCommunities(String userId, Integer limit, String cursor) {
        return readModel.userCommunities(userId, limit, cursor);
    }

    MembershipResponse joinCommunity(String communityId, MembershipJoinRequest request) {
        return writeModel.joinCommunity(communityId, request);
    }

    void leaveCommunity(String communityId, String userId) {
        writeModel.leaveCommunity(communityId, userId);
    }

    CircleMembershipRequestResponse requestCommunityJoin(
            String communityId,
            CircleMembershipRequestCreateRequest request) {
        return writeModel.requestCommunityJoin(communityId, request);
    }

    CircleMembershipRequestListResponse communityJoinRequests(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.communityJoinRequests(communityId, actorUserId, status, limit, cursor);
    }

    CircleMembershipRequestResponse decideCommunityJoinRequest(
            String communityId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return writeModel.decideCommunityJoinRequest(communityId, requestId, request);
    }

    CircleMembershipRequestResponse inviteCommunityMember(
            String communityId,
            CircleMembershipInviteCreateRequest request) {
        return writeModel.inviteCommunityMember(communityId, request);
    }

    CircleMembershipRequestListResponse communityInvites(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.communityInvites(communityId, actorUserId, status, limit, cursor);
    }

    CircleMembershipRequestResponse decideCommunityInvite(
            String communityId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        return writeModel.decideCommunityInvite(communityId, requestId, request);
    }

    void removeCommunityMember(String communityId, String memberId, String actorUserId) {
        writeModel.removeCommunityMember(communityId, memberId, actorUserId);
    }

    MembershipResponse updateCommunityMemberRole(
            String communityId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        return writeModel.updateCommunityMemberRole(communityId, memberId, request, actorUserId);
    }

    CircleOwnershipTransferResponse transferCommunityOwnership(
            String communityId,
            CircleOwnershipTransferRequest request) {
        return writeModel.transferCommunityOwnership(communityId, request);
    }

    SocialCircleContentListResponse communityContent(
            String communityId,
            String viewerId,
            Integer limit,
            String cursor) {
        return readModel.communityContent(communityId, viewerId, limit, cursor);
    }

    CircleContentModerationResponse moderateCommunityContent(
            String communityId,
            String contentId,
            CircleContentModerationRequest request) {
        return writeModel.moderateCommunityContent(communityId, contentId, request);
    }

    CircleContentModerationListResponse communityContentModeration(
            String communityId,
            String actorUserId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.communityContentModeration(communityId, actorUserId, status, limit, cursor);
    }

    CircleMembershipRequestListResponse userCircleInvites(
            String userId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.userCircleInvites(userId, status, limit, cursor);
    }

    CircleMembershipRequestListResponse userCircleJoinRequests(
            String userId,
            String status,
            Integer limit,
            String cursor) {
        return readModel.userCircleJoinRequests(userId, status, limit, cursor);
    }

    static Limits defaultLimits() {
        return new Limits(
                DEFAULT_DIRECTORY_LIMIT,
                DEFAULT_MEMBERSHIP_LIMIT,
                DEFAULT_CONTENT_LIMIT,
                DEFAULT_REQUEST_LIMIT,
                DEFAULT_MODERATION_LIMIT);
    }

    /**
     * Defines endpoint list limits for circle directories, memberships, content, requests, and moderation queues.
     */
    record Limits(
            int directoryLimit,
            int membershipLimit,
            int contentLimit,
            int requestLimit,
            int moderationLimit) {
    }
}
