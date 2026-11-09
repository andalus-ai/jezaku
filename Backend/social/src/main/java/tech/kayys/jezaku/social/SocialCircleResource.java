package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
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

@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialCircleResource {
    @Inject
    SocialService service;

    @POST
    @Path("/groups")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createGroup(SocialGroupCreateRequest request) {
        return service.createGroup(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/groups")
    public Uni<SocialGroupListResponse> groups(
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor,
            @QueryParam("q") String query,
            @QueryParam("visibility") @DefaultValue("all") String visibility,
            @QueryParam("viewerId") String viewerId) {
        return service.groups(limit, cursor, query, visibility, viewerId);
    }

    @GET
    @Path("/groups/{groupId}")
    public Uni<SocialGroupResponse> group(@PathParam("groupId") String groupId) {
        return service.group(groupId);
    }

    @PUT
    @Path("/groups/{groupId}/members")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<MembershipResponse> addGroupMember(
            @PathParam("groupId") String groupId,
            @QueryParam("actorUserId") String actorUserId,
            MembershipCreateRequest request) {
        return service.addGroupMember(groupId, request, actorUserId);
    }

    @GET
    @Path("/groups/{groupId}/members")
    public Uni<MembershipListResponse> groupMembers(
            @PathParam("groupId") String groupId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.groupMembers(groupId, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/groups")
    public Uni<MembershipListResponse> userGroups(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userGroups(userId, limit, cursor);
    }

    @PUT
    @Path("/groups/{groupId}/join")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<MembershipResponse> joinGroup(
            @PathParam("groupId") String groupId,
            MembershipJoinRequest request) {
        return service.joinGroup(groupId, request);
    }

    @DELETE
    @Path("/groups/{groupId}/leave/{userId}")
    public Uni<Response> leaveGroup(
            @PathParam("groupId") String groupId,
            @PathParam("userId") String userId) {
        return service.leaveGroup(groupId, userId)
                .replaceWith(Response.noContent().build());
    }

    @POST
    @Path("/groups/{groupId}/join-requests")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> requestGroupJoin(
            @PathParam("groupId") String groupId,
            CircleMembershipRequestCreateRequest request) {
        return service.requestGroupJoin(groupId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/groups/{groupId}/join-requests")
    public Uni<CircleMembershipRequestListResponse> groupJoinRequests(
            @PathParam("groupId") String groupId,
            @QueryParam("actorUserId") String actorUserId,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.groupJoinRequests(groupId, actorUserId, status, limit, cursor);
    }

    @PUT
    @Path("/groups/{groupId}/join-requests/{requestId}/decision")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleMembershipRequestResponse> decideGroupJoinRequest(
            @PathParam("groupId") String groupId,
            @PathParam("requestId") String requestId,
            CircleMembershipDecisionRequest request) {
        return service.decideGroupJoinRequest(groupId, requestId, request);
    }

    @POST
    @Path("/groups/{groupId}/invites")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> inviteGroupMember(
            @PathParam("groupId") String groupId,
            CircleMembershipInviteCreateRequest request) {
        return service.inviteGroupMember(groupId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/groups/{groupId}/invites")
    public Uni<CircleMembershipRequestListResponse> groupInvites(
            @PathParam("groupId") String groupId,
            @QueryParam("actorUserId") String actorUserId,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.groupInvites(groupId, actorUserId, status, limit, cursor);
    }

    @PUT
    @Path("/groups/{groupId}/invites/{requestId}/decision")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleMembershipRequestResponse> decideGroupInvite(
            @PathParam("groupId") String groupId,
            @PathParam("requestId") String requestId,
            CircleMembershipDecisionRequest request) {
        return service.decideGroupInvite(groupId, requestId, request);
    }

    @DELETE
    @Path("/groups/{groupId}/members/{memberId}")
    public Uni<Response> removeGroupMember(
            @PathParam("groupId") String groupId,
            @PathParam("memberId") String memberId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.removeGroupMember(groupId, memberId, actorUserId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/groups/{groupId}/members/{memberId}/role")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<MembershipResponse> updateGroupMemberRole(
            @PathParam("groupId") String groupId,
            @PathParam("memberId") String memberId,
            @QueryParam("actorUserId") String actorUserId,
            MembershipRoleUpdateRequest request) {
        return service.updateGroupMemberRole(groupId, memberId, request, actorUserId);
    }

    @PUT
    @Path("/groups/{groupId}/ownership-transfer")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleOwnershipTransferResponse> transferGroupOwnership(
            @PathParam("groupId") String groupId,
            CircleOwnershipTransferRequest request) {
        return service.transferGroupOwnership(groupId, request);
    }

    @GET
    @Path("/groups/{groupId}/content")
    public Uni<SocialCircleContentListResponse> groupContent(
            @PathParam("groupId") String groupId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.groupContent(groupId, viewerId, limit, cursor);
    }

    @PUT
    @Path("/groups/{groupId}/content/{contentId}/moderation")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleContentModerationResponse> moderateGroupContent(
            @PathParam("groupId") String groupId,
            @PathParam("contentId") String contentId,
            CircleContentModerationRequest request) {
        return service.moderateGroupContent(groupId, contentId, request);
    }

    @GET
    @Path("/groups/{groupId}/content-moderation")
    public Uni<CircleContentModerationListResponse> groupContentModeration(
            @PathParam("groupId") String groupId,
            @QueryParam("actorUserId") String actorUserId,
            @QueryParam("status") @DefaultValue("removed") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.groupContentModeration(groupId, actorUserId, status, limit, cursor);
    }

    @POST
    @Path("/communities")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createCommunity(SocialCommunityCreateRequest request) {
        return service.createCommunity(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/communities")
    public Uni<SocialCommunityListResponse> communities(
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor,
            @QueryParam("q") String query,
            @QueryParam("visibility") @DefaultValue("all") String visibility,
            @QueryParam("viewerId") String viewerId) {
        return service.communities(limit, cursor, query, visibility, viewerId);
    }

    @GET
    @Path("/communities/{communityId}")
    public Uni<SocialCommunityResponse> community(@PathParam("communityId") String communityId) {
        return service.community(communityId);
    }

    @PUT
    @Path("/communities/{communityId}/members")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<MembershipResponse> addCommunityMember(
            @PathParam("communityId") String communityId,
            @QueryParam("actorUserId") String actorUserId,
            MembershipCreateRequest request) {
        return service.addCommunityMember(communityId, request, actorUserId);
    }

    @GET
    @Path("/communities/{communityId}/members")
    public Uni<MembershipListResponse> communityMembers(
            @PathParam("communityId") String communityId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.communityMembers(communityId, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/communities")
    public Uni<MembershipListResponse> userCommunities(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userCommunities(userId, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/circle-invites")
    public Uni<CircleMembershipRequestListResponse> userCircleInvites(
            @PathParam("userId") String userId,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userCircleInvites(userId, status, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/circle-join-requests")
    public Uni<CircleMembershipRequestListResponse> userCircleJoinRequests(
            @PathParam("userId") String userId,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userCircleJoinRequests(userId, status, limit, cursor);
    }

    @PUT
    @Path("/communities/{communityId}/join")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<MembershipResponse> joinCommunity(
            @PathParam("communityId") String communityId,
            MembershipJoinRequest request) {
        return service.joinCommunity(communityId, request);
    }

    @DELETE
    @Path("/communities/{communityId}/leave/{userId}")
    public Uni<Response> leaveCommunity(
            @PathParam("communityId") String communityId,
            @PathParam("userId") String userId) {
        return service.leaveCommunity(communityId, userId)
                .replaceWith(Response.noContent().build());
    }

    @POST
    @Path("/communities/{communityId}/join-requests")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> requestCommunityJoin(
            @PathParam("communityId") String communityId,
            CircleMembershipRequestCreateRequest request) {
        return service.requestCommunityJoin(communityId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/communities/{communityId}/join-requests")
    public Uni<CircleMembershipRequestListResponse> communityJoinRequests(
            @PathParam("communityId") String communityId,
            @QueryParam("actorUserId") String actorUserId,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.communityJoinRequests(communityId, actorUserId, status, limit, cursor);
    }

    @PUT
    @Path("/communities/{communityId}/join-requests/{requestId}/decision")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleMembershipRequestResponse> decideCommunityJoinRequest(
            @PathParam("communityId") String communityId,
            @PathParam("requestId") String requestId,
            CircleMembershipDecisionRequest request) {
        return service.decideCommunityJoinRequest(communityId, requestId, request);
    }

    @POST
    @Path("/communities/{communityId}/invites")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> inviteCommunityMember(
            @PathParam("communityId") String communityId,
            CircleMembershipInviteCreateRequest request) {
        return service.inviteCommunityMember(communityId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/communities/{communityId}/invites")
    public Uni<CircleMembershipRequestListResponse> communityInvites(
            @PathParam("communityId") String communityId,
            @QueryParam("actorUserId") String actorUserId,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.communityInvites(communityId, actorUserId, status, limit, cursor);
    }

    @PUT
    @Path("/communities/{communityId}/invites/{requestId}/decision")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleMembershipRequestResponse> decideCommunityInvite(
            @PathParam("communityId") String communityId,
            @PathParam("requestId") String requestId,
            CircleMembershipDecisionRequest request) {
        return service.decideCommunityInvite(communityId, requestId, request);
    }

    @DELETE
    @Path("/communities/{communityId}/members/{memberId}")
    public Uni<Response> removeCommunityMember(
            @PathParam("communityId") String communityId,
            @PathParam("memberId") String memberId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.removeCommunityMember(communityId, memberId, actorUserId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/communities/{communityId}/members/{memberId}/role")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<MembershipResponse> updateCommunityMemberRole(
            @PathParam("communityId") String communityId,
            @PathParam("memberId") String memberId,
            @QueryParam("actorUserId") String actorUserId,
            MembershipRoleUpdateRequest request) {
        return service.updateCommunityMemberRole(communityId, memberId, request, actorUserId);
    }

    @PUT
    @Path("/communities/{communityId}/ownership-transfer")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleOwnershipTransferResponse> transferCommunityOwnership(
            @PathParam("communityId") String communityId,
            CircleOwnershipTransferRequest request) {
        return service.transferCommunityOwnership(communityId, request);
    }

    @GET
    @Path("/communities/{communityId}/content")
    public Uni<SocialCircleContentListResponse> communityContent(
            @PathParam("communityId") String communityId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.communityContent(communityId, viewerId, limit, cursor);
    }

    @PUT
    @Path("/communities/{communityId}/content/{contentId}/moderation")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CircleContentModerationResponse> moderateCommunityContent(
            @PathParam("communityId") String communityId,
            @PathParam("contentId") String contentId,
            CircleContentModerationRequest request) {
        return service.moderateCommunityContent(communityId, contentId, request);
    }

    @GET
    @Path("/communities/{communityId}/content-moderation")
    public Uni<CircleContentModerationListResponse> communityContentModeration(
            @PathParam("communityId") String communityId,
            @QueryParam("actorUserId") String actorUserId,
            @QueryParam("status") @DefaultValue("removed") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.communityContentModeration(communityId, actorUserId, status, limit, cursor);
    }
}
