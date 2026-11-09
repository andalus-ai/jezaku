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
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;

@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialRelationshipResource {
    @Inject
    SocialService service;

    @POST
    @Path("/friend-requests")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createFriendRequest(FriendRequestCreateRequest request) {
        return service.createFriendRequest(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/friend-requests/{userId}")
    public Uni<FriendRequestListResponse> friendRequests(
            @PathParam("userId") String userId,
            @QueryParam("direction") @DefaultValue("incoming") String direction,
            @QueryParam("status") @DefaultValue("all") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.friendRequests(userId, direction, status, limit, cursor);
    }

    @POST
    @Path("/friend-requests/{requestId}/accept")
    public Uni<FriendRequestResponse> acceptRequest(
            @PathParam("requestId") String requestId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.acceptRequest(requestId, actorUserId);
    }

    @POST
    @Path("/friend-requests/{requestId}/decline")
    public Uni<FriendRequestResponse> declineRequest(
            @PathParam("requestId") String requestId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.declineRequest(requestId, actorUserId);
    }

    @GET
    @Path("/friends/{userId}")
    public Uni<FriendListResponse> friends(
            @PathParam("userId") String userId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.friends(userId, viewerId, limit, cursor);
    }

    @DELETE
    @Path("/friends/{userId}/{friendId}")
    public Uni<Response> removeFriend(
            @PathParam("userId") String userId,
            @PathParam("friendId") String friendId) {
        return service.removeFriend(userId, friendId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/users/{followedUserId}/followers")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialUserFollowResponse> followUser(
            @PathParam("followedUserId") String followedUserId,
            SocialUserFollowRequest request) {
        return service.followUser(followedUserId, request);
    }

    @DELETE
    @Path("/users/{followedUserId}/followers/{followerId}")
    public Uni<Response> unfollowUser(
            @PathParam("followedUserId") String followedUserId,
            @PathParam("followerId") String followerId) {
        return service.unfollowUser(followedUserId, followerId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/users/{userId}/followers")
    public Uni<SocialUserFollowListResponse> followers(
            @PathParam("userId") String userId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.followers(userId, viewerId, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/following")
    public Uni<SocialUserFollowListResponse> following(
            @PathParam("userId") String userId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.following(userId, viewerId, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/follow-requests")
    public Uni<SocialUserFollowRequestListResponse> userFollowRequests(
            @PathParam("userId") String userId,
            @QueryParam("direction") @DefaultValue("incoming") String direction,
            @QueryParam("status") @DefaultValue("pending") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userFollowRequests(userId, direction, status, limit, cursor);
    }

    @PUT
    @Path("/users/{followedUserId}/follow-requests/{followerId}/decision")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialUserFollowResponse> decideUserFollowRequest(
            @PathParam("followedUserId") String followedUserId,
            @PathParam("followerId") String followerId,
            SocialUserFollowDecisionRequest request) {
        return service.decideUserFollowRequest(followedUserId, followerId, request);
    }

    @GET
    @Path("/users/{userId}/following-feed")
    public Uni<SocialFeedResponse> followingFeed(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.followingFeed(userId, limit, cursor);
    }

    @GET
    @Path("/close-friends/{userId}")
    public Uni<FriendListResponse> closeFriends(
            @PathParam("userId") String userId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.closeFriends(userId, viewerId, limit, cursor);
    }

    @PUT
    @Path("/close-friends/{userId}/{friendId}")
    public Uni<FriendSummary> addCloseFriend(
            @PathParam("userId") String userId,
            @PathParam("friendId") String friendId) {
        return service.addCloseFriend(userId, friendId);
    }

    @DELETE
    @Path("/close-friends/{userId}/{friendId}")
    public Uni<Response> removeCloseFriend(
            @PathParam("userId") String userId,
            @PathParam("friendId") String friendId) {
        return service.removeCloseFriend(userId, friendId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/blocks")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<BlockResponse> block(BlockRequest request) {
        return service.block(request);
    }

    @GET
    @Path("/blocks/{userId}")
    public Uni<BlockListResponse> blocks(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.blocks(userId, limit, cursor);
    }

    @DELETE
    @Path("/blocks/{userId}/{blockedUserId}")
    public Uni<Response> unblock(
            @PathParam("userId") String userId,
            @PathParam("blockedUserId") String blockedUserId) {
        return service.unblock(userId, blockedUserId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/mutes")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialMuteResponse> mute(SocialMuteRequest request) {
        return service.mute(request);
    }

    @GET
    @Path("/users/{userId}/mutes")
    public Uni<SocialMuteListResponse> mutes(
            @PathParam("userId") String userId,
            @QueryParam("targetType") @DefaultValue("all") String targetType,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.mutes(userId, targetType, limit, cursor);
    }

    @DELETE
    @Path("/mutes/{userId}/{targetType}/{targetId}")
    public Uni<Response> unmute(
            @PathParam("userId") String userId,
            @PathParam("targetType") String targetType,
            @PathParam("targetId") String targetId) {
        return service.unmute(userId, targetType, targetId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/family")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<FamilyLinkResponse> createFamilyLink(FamilyLinkCreateRequest request) {
        return service.createFamilyLink(request);
    }

    @GET
    @Path("/family/{userId}")
    public Uni<FamilyLinkListResponse> family(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.family(userId, limit, cursor);
    }

    @DELETE
    @Path("/family/{userId}/{relativeId}")
    public Uni<Response> removeFamilyLink(
            @PathParam("userId") String userId,
            @PathParam("relativeId") String relativeId) {
        return service.removeFamilyLink(userId, relativeId)
                .replaceWith(Response.noContent().build());
    }
}
