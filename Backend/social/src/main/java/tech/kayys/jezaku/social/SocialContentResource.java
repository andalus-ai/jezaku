package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentHideResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentReportRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialFollowedTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialHiddenContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMentionListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialSaveResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSavedContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialShareCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialShareListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialTagFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTopicFeedResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialTrendingTagListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserContentListResponse;

@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialContentResource {
    @Inject
    SocialService service;

    @GET
    @Path("/users/{userId}/content")
    public Uni<SocialUserContentListResponse> userContent(
            @PathParam("userId") String userId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userContent(userId, viewerId, limit, cursor);
    }

    @POST
    @Path("/content")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createContent(SocialContentCreateRequest request) {
        return service.createContent(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @PATCH
    @Path("/content/{contentId}")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialContentResponse> updateContent(
            @PathParam("contentId") String contentId,
            SocialContentUpdateRequest request) {
        return service.updateContent(contentId, request);
    }

    @DELETE
    @Path("/content/{contentId}")
    public Uni<Response> deleteContent(
            @PathParam("contentId") String contentId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.deleteContent(contentId, actorUserId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/content/{contentId}")
    public Uni<SocialContentResponse> content(
            @PathParam("contentId") String contentId,
            @QueryParam("viewerId") String viewerId) {
        return service.content(contentId, viewerId);
    }

    @POST
    @Path("/content/access")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialContentAccessResponse> contentAccess(SocialContentAccessRequest request) {
        return service.contentAccess(request);
    }

    @GET
    @Path("/tags/{tag}/content")
    public Uni<SocialTagContentListResponse> tagContent(
            @PathParam("tag") String tag,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.tagContent(tag, viewerId, limit, cursor);
    }

    @GET
    @Path("/tags/trending")
    public Uni<SocialTrendingTagListResponse> trendingTags(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("20") Integer limit) {
        return service.trendingTags(viewerId, limit);
    }

    @PUT
    @Path("/tags/{tag}/follows")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialTagFollowResponse> followTag(
            @PathParam("tag") String tag,
            SocialTagFollowRequest request) {
        return service.followTag(tag, request);
    }

    @DELETE
    @Path("/tags/{tag}/follows/{userId}")
    public Uni<Response> unfollowTag(
            @PathParam("tag") String tag,
            @PathParam("userId") String userId) {
        return service.unfollowTag(tag, userId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/users/{userId}/followed-tags")
    public Uni<SocialFollowedTagListResponse> followedTags(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("50") Integer limit) {
        return service.followedTags(userId, limit);
    }

    @GET
    @Path("/users/{userId}/topic-feed")
    public Uni<SocialTopicFeedResponse> topicFeed(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.topicFeed(userId, limit, cursor);
    }

    @PUT
    @Path("/content/{contentId}/likes")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialReactionResponse> likeContent(
            @PathParam("contentId") String contentId,
            SocialReactionRequest request) {
        return service.likeContent(contentId, request);
    }

    @DELETE
    @Path("/content/{contentId}/likes/{userId}")
    public Uni<Response> unlikeContent(
            @PathParam("contentId") String contentId,
            @PathParam("userId") String userId) {
        return service.unlikeContent(contentId, userId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/content/{contentId}/saves")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialSaveResponse> saveContent(
            @PathParam("contentId") String contentId,
            SocialSaveRequest request) {
        return service.saveContent(contentId, request);
    }

    @DELETE
    @Path("/content/{contentId}/saves/{userId}")
    public Uni<Response> unsaveContent(
            @PathParam("contentId") String contentId,
            @PathParam("userId") String userId) {
        return service.unsaveContent(contentId, userId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/users/{userId}/saved-content")
    public Uni<SocialSavedContentListResponse> savedContent(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.savedContent(userId, limit, cursor);
    }

    @POST
    @Path("/content/{contentId}/shares")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> shareContent(
            @PathParam("contentId") String contentId,
            SocialShareCreateRequest request) {
        return service.shareContent(contentId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/content/{contentId}/shares")
    public Uni<SocialShareListResponse> shares(
            @PathParam("contentId") String contentId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("25") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.shares(contentId, viewerId, limit, cursor);
    }

    @PUT
    @Path("/content/{contentId}/hides")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialContentHideResponse> hideContent(
            @PathParam("contentId") String contentId,
            SocialContentHideRequest request) {
        return service.hideContent(contentId, request);
    }

    @DELETE
    @Path("/content/{contentId}/hides/{userId}")
    public Uni<Response> unhideContent(
            @PathParam("contentId") String contentId,
            @PathParam("userId") String userId) {
        return service.unhideContent(contentId, userId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/users/{userId}/hidden-content")
    public Uni<SocialHiddenContentListResponse> hiddenContent(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.hiddenContent(userId, limit, cursor);
    }

    @POST
    @Path("/content/{contentId}/reports")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> reportContent(
            @PathParam("contentId") String contentId,
            SocialContentReportRequest request) {
        return service.reportContent(contentId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/content-reports")
    public Uni<SocialContentReportListResponse> contentReports(
            @QueryParam("status") @DefaultValue("open") String status,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.contentReports(status, limit, cursor);
    }

    @GET
    @Path("/content/{contentId}/mentions")
    public Uni<SocialMentionListResponse> contentMentions(
            @PathParam("contentId") String contentId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("25") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.contentMentions(contentId, viewerId, limit, cursor);
    }

    @GET
    @Path("/users/{userId}/mentions")
    public Uni<SocialMentionListResponse> userMentions(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.userMentions(userId, limit, cursor);
    }

    @POST
    @Path("/content/{contentId}/comments")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> addComment(
            @PathParam("contentId") String contentId,
            SocialCommentCreateRequest request) {
        return service.addComment(contentId, request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/content/{contentId}/comments")
    public Uni<SocialCommentListResponse> comments(
            @PathParam("contentId") String contentId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("parentCommentId") String parentCommentId,
            @QueryParam("limit") @DefaultValue("25") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.comments(contentId, viewerId, parentCommentId, limit, cursor);
    }

    @PUT
    @Path("/content/{contentId}/comments/{commentId}/likes")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialCommentReactionResponse> likeComment(
            @PathParam("contentId") String contentId,
            @PathParam("commentId") String commentId,
            SocialReactionRequest request) {
        return service.likeComment(contentId, commentId, request);
    }

    @DELETE
    @Path("/content/{contentId}/comments/{commentId}/likes/{userId}")
    public Uni<Response> unlikeComment(
            @PathParam("contentId") String contentId,
            @PathParam("commentId") String commentId,
            @PathParam("userId") String userId) {
        return service.unlikeComment(contentId, commentId, userId)
                .replaceWith(Response.noContent().build());
    }

    @DELETE
    @Path("/content/{contentId}/comments/{commentId}")
    public Uni<Response> removeComment(
            @PathParam("contentId") String contentId,
            @PathParam("commentId") String commentId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.removeComment(contentId, commentId, actorUserId)
                .replaceWith(Response.noContent().build());
    }
}
