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
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorHistoryResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryFeedResponse;
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

    @POST
    public Uni<Response> create(MemoryCreateRequest request) {
        return service.create(request)
                .map(memory -> Response.status(Response.Status.CREATED).entity(memory).build());
    }

    @GET
    @Path("/{id}")
    public Uni<MemoryResponse> get(
            @PathParam("id") String id,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.get(id, lat, lng);
    }

    @PATCH
    @Path("/{id}/anchor")
    public Uni<MemoryResponse> updateAnchor(
            @PathParam("id") String id,
            MemoryAnchorUpdateRequest request) {
        return service.updateAnchor(id, request);
    }

    @GET
    @Path("/{id}/anchor/history")
    public Uni<MemoryAnchorHistoryResponse> anchorHistory(
            @PathParam("id") String id,
            @QueryParam("ownerId") String ownerId) {
        return service.anchorHistory(id, ownerId);
    }

    @PUT
    @Path("/media/{mediaId}/snapshot")
    public Uni<MemoryMediaSnapshotUpdateResponse> updateMediaSnapshot(
            @PathParam("mediaId") String mediaId,
            MemoryMediaSnapshotUpdateRequest request) {
        return service.updateMediaSnapshot(mediaId, request);
    }

    @PUT
    @Path("/media/snapshots")
    public Uni<MemoryMediaSnapshotApplyResponse<MemoryMediaSnapshotUpdateResponse>> updateMediaSnapshots(
            MemoryMediaSnapshotBatchRequest request) {
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
        return service.nearbyDots(lat, lng, radiusMeters, excludeOwnerId);
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
                limit);
    }

    @GET
    @Path("/feed")
    public Uni<List<MemoryResponse>> feed(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.feed(lat, lng);
    }

    @GET
    @Path("/users/{userId}")
    public Uni<MemoryFeedResponse> userMemories(@PathParam("userId") String userId) {
        return service.userMemories(userId);
    }

    @DELETE
    @Path("/{id}")
    public Uni<Response> delete(@PathParam("id") String id) {
        return service.delete(id)
                .replaceWith(Response.noContent().build());
    }

    private void requireCoordinates(Double lat, Double lng) {
        if (lat == null || lng == null) {
            throw new BadRequestException("lat and lng query parameters are required");
        }
    }
}
