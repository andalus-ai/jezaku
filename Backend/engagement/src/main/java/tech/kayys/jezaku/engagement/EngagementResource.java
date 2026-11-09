package tech.kayys.jezaku.engagement;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.engagement.EngagementDtos.BookmarkListResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.BookmarkRequest;
import tech.kayys.jezaku.engagement.EngagementDtos.BookmarkResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentCreateRequest;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentListResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.CommentResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.EngagementSummaryResponse;
import tech.kayys.jezaku.engagement.EngagementDtos.ReactionRequest;
import tech.kayys.jezaku.engagement.EngagementDtos.ReactionResponse;

@Path("/engagement")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class EngagementResource {
    @Inject
    EngagementService service;

    @POST
    @Path("/reactions")
    public Uni<ReactionResponse> react(ReactionRequest request) {
        return service.react(request);
    }

    @DELETE
    @Path("/reactions")
    public Uni<Response> removeReaction(
            @QueryParam("userId") String userId,
            @QueryParam("targetType") String targetType,
            @QueryParam("targetId") String targetId) {
        return service.removeReaction(userId, targetType, targetId)
                .replaceWith(Response.noContent().build());
    }

    @POST
    @Path("/comments")
    public Uni<Response> comment(CommentCreateRequest request) {
        return service.comment(request)
                .map(comment -> Response.status(Response.Status.CREATED).entity(comment).build());
    }

    @GET
    @Path("/targets/{targetType}/{targetId}/comments")
    public Uni<CommentListResponse> comments(
            @PathParam("targetType") String targetType,
            @PathParam("targetId") String targetId) {
        return service.comments(targetType, targetId);
    }

    @DELETE
    @Path("/comments/{commentId}")
    public Uni<Response> deleteComment(
            @PathParam("commentId") String commentId,
            @QueryParam("userId") String userId) {
        return service.deleteComment(commentId, userId)
                .replaceWith(Response.noContent().build());
    }

    @POST
    @Path("/bookmarks")
    public Uni<BookmarkResponse> bookmark(BookmarkRequest request) {
        return service.bookmark(request);
    }

    @DELETE
    @Path("/bookmarks")
    public Uni<Response> removeBookmark(
            @QueryParam("userId") String userId,
            @QueryParam("targetType") String targetType,
            @QueryParam("targetId") String targetId) {
        return service.removeBookmark(userId, targetType, targetId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/users/{userId}/bookmarks")
    public Uni<BookmarkListResponse> bookmarks(@PathParam("userId") String userId) {
        return service.bookmarks(userId);
    }

    @GET
    @Path("/targets/{targetType}/{targetId}/summary")
    public Uni<EngagementSummaryResponse> summary(
            @PathParam("targetType") String targetType,
            @PathParam("targetId") String targetId,
            @QueryParam("viewerId") String viewerId) {
        return service.summary(targetType, targetId, viewerId);
    }
}
