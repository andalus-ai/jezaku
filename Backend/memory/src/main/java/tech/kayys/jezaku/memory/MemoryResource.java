package tech.kayys.jezaku.memory;

import io.smallrye.common.annotation.Blocking;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedUser;
import tech.kayys.jezaku.auth.ServiceScopes;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorHistoryResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryFeedResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryFrameStyleUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMediaSnapshotUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMediaSnapshotUpdateResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMinimapResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MiniMapDot;

import java.util.List;

@Path("/memories")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class MemoryResource {
    @Inject
    MemoryService service;

    @Context
    ContainerRequestContext requestContext;

    private void self(String userId) {
        AuthContext.requireSelf(requestContext, userId);
    }

    /** The authenticated caller, or null while authentication is not enforced. */
    private String caller() {
        return AuthContext.user(requestContext).map(AuthenticatedUser::userId).orElse(null);
    }

    @POST
    public Uni<Response> create(MemoryCreateRequest request) {
        self(request == null ? null : request.ownerId());
        return service.create(request)
                .map(memory -> Response.status(Response.Status.CREATED).entity(memory).build());
    }

    @GET
    @Path("/{id}")
    public Uni<MemoryResponse> get(
            @PathParam("id") String id,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.get(id, lat, lng, caller());
    }

    /** Internal: other services resolve a memory's owner here; users have no use for it. */
    @GET
    @Path("/{id}/owner")
    public Uni<MemoryDtos.MemoryOwnerResponse> owner(@PathParam("id") String id) {
        AuthContext.requireService(requestContext, ServiceScopes.MEMORY_READ);
        return service.owner(id);
    }

    @PATCH
    @Path("/{id}/anchor")
    public Uni<MemoryResponse> updateAnchor(
            @PathParam("id") String id,
            MemoryAnchorUpdateRequest request) {
        self(request == null ? null : request.ownerId());
        return service.updateAnchor(id, request);
    }

    /** The owner changes the look of a published frame. A blank {@code frameStyle} restores the default. */
    @PATCH
    @Path("/{id}/frame-style")
    public Uni<MemoryResponse> updateFrameStyle(
            @PathParam("id") String id,
            MemoryFrameStyleUpdateRequest request) {
        self(request == null ? null : request.ownerId());
        return service.updateFrameStyle(id, request);
    }

    @GET
    @Path("/{id}/anchor/history")
    public Uni<MemoryAnchorHistoryResponse> anchorHistory(
            @PathParam("id") String id,
            @QueryParam("ownerId") String ownerId) {
        self(ownerId);
        return service.anchorHistory(id, ownerId);
    }

    @PUT
    @Path("/media/{mediaId}/snapshot")
    public Uni<MemoryMediaSnapshotUpdateResponse> updateMediaSnapshot(
            @PathParam("mediaId") String mediaId,
            MemoryMediaSnapshotUpdateRequest request) {
        AuthContext.requireService(requestContext, ServiceScopes.MEMORY_MEDIA_SYNC);
        return service.updateMediaSnapshot(mediaId, request);
    }

    @PUT
    @Path("/media/snapshots")
    public Uni<MemoryMediaSnapshotApplyResponse<MemoryMediaSnapshotUpdateResponse>> updateMediaSnapshots(
            MemoryMediaSnapshotBatchRequest request) {
        AuthContext.requireService(requestContext, ServiceScopes.MEMORY_MEDIA_SYNC);
        return service.updateMediaSnapshots(request);
    }

    @GET
    @Path("/nearby")
    public Uni<List<MiniMapDot>> nearby(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("radiusMeters") @DefaultValue("100") Double radiusMeters,
            @QueryParam("excludeOwnerId") String excludeOwnerId) {
        requireCoordinates(lat, lng);
        return service.nearbyDots(lat, lng, radiusMeters, excludeOwnerId, caller());
    }

    @GET
    @Path("/minimap")
    public Uni<MemoryMinimapResponse> minimap(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("radiusMeters") @DefaultValue("100") Double radiusMeters,
            @QueryParam("excludeOwnerId") String excludeOwnerId,
            @QueryParam("limit") @DefaultValue("50") Integer limit) {
        requireCoordinates(lat, lng);
        return service.minimap(
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                radiusMeters,
                excludeOwnerId,
                limit,
                caller());
    }

    @GET
    @Path("/feed")
    public Uni<List<MemoryResponse>> feed(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.feed(lat, lng, caller());
    }

    @GET
    @Path("/users/{userId}")
    public Uni<MemoryFeedResponse> userMemories(@PathParam("userId") String userId) {
        return service.userMemories(userId, caller());
    }

    @DELETE
    @Path("/{id}")
    public Uni<Response> delete(@PathParam("id") String id) {
        return service.delete(id, caller())
                .replaceWith(Response.noContent().build());
    }

    private void requireCoordinates(Double lat, Double lng) {
        if (lat == null || lng == null) {
            throw new BadRequestException("lat and lng query parameters are required");
        }
    }
}
