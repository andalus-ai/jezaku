package tech.kayys.jezaku.media;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.media.MediaDtos.MediaLifecycleEventsResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaListResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchHistoryResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncOpsResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunHistoryResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRetryRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncStatusResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncStatusesResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaReferenceBatchRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaReferenceBatchResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaReferenceResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaSyncCheckpointRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaSyncCheckpointResponse;
import tech.kayys.jezaku.media.MediaDtos.ModerationHistoryResponse;
import tech.kayys.jezaku.media.MediaDtos.ModerationUpdateRequest;
import tech.kayys.jezaku.media.MediaDtos.UploadCompleteRequest;
import tech.kayys.jezaku.media.MediaDtos.UploadCreateRequest;

@Path("/media")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class MediaResource {
    @Inject
    MediaService service;

    @POST
    @Path("/uploads")
    public Uni<Response> createUpload(UploadCreateRequest request) {
        return service.createUpload(request)
                .map(upload -> Response.status(Response.Status.CREATED).entity(upload).build());
    }

    @POST
    @Path("/uploads/{uploadId}/complete")
    public Uni<MediaResponse> completeUpload(
            @PathParam("uploadId") String uploadId,
            UploadCompleteRequest request) {
        return service.completeUpload(uploadId, request);
    }

    @GET
    @Path("/{mediaId}/reference")
    public Uni<MediaReferenceResponse> reference(@PathParam("mediaId") String mediaId) {
        return service.reference(mediaId);
    }

    @POST
    @Path("/references")
    public Uni<MediaReferenceBatchResponse> references(MediaReferenceBatchRequest request) {
        return service.references(request);
    }

    @GET
    @Path("/events")
    public Uni<MediaLifecycleEventsResponse> lifecycleEvents(
            @QueryParam("afterSequence") Long afterSequence,
            @QueryParam("limit") Integer limit) {
        return service.lifecycleEvents(afterSequence, limit);
    }

    @GET
    @Path("/events/memory-snapshots")
    public Uni<MediaMemorySnapshotSyncResponse> memorySnapshotSync(
            @QueryParam("consumerId") String consumerId,
            @QueryParam("afterSequence") Long afterSequence,
            @QueryParam("limit") Integer limit) {
        return service.memorySnapshotSync(consumerId, afterSequence, limit);
    }

    @POST
    @Path("/events/memory-snapshots/sync")
    public Uni<MediaMemorySnapshotSyncRunResponse> runMemorySnapshotSync(
            MediaMemorySnapshotSyncRunRequest request) {
        return service.runMemorySnapshotSync(request);
    }

    @POST
    @Path("/events/memory-snapshots/retry")
    public Uni<MediaMemorySnapshotSyncRunResponse> retryMemorySnapshotSync(
            MediaMemorySnapshotSyncRetryRequest request) {
        return service.retryMemorySnapshotSync(request);
    }

    @POST
    @Path("/events/memory-snapshots/dispatch")
    public Uni<MediaMemorySnapshotSyncDispatchResponse> dispatchMemorySnapshotSync(
            MediaMemorySnapshotSyncDispatchRequest request) {
        return service.dispatchMemorySnapshotSync(request);
    }

    @GET
    @Path("/events/memory-snapshots/dispatches")
    public Uni<MediaMemorySnapshotSyncDispatchHistoryResponse> memorySnapshotSyncDispatches(
            @QueryParam("limit") Integer limit) {
        return service.memorySnapshotSyncDispatches(limit);
    }

    @GET
    @Path("/events/memory-snapshots/runs")
    public Uni<MediaMemorySnapshotSyncRunHistoryResponse> memorySnapshotSyncRuns(
            @QueryParam("consumerId") String consumerId,
            @QueryParam("limit") Integer limit) {
        return service.memorySnapshotSyncRuns(consumerId, limit);
    }

    @GET
    @Path("/events/memory-snapshots/status")
    public Uni<MediaMemorySnapshotSyncStatusResponse> memorySnapshotSyncStatus(
            @QueryParam("consumerId") String consumerId) {
        return service.memorySnapshotSyncStatus(consumerId);
    }

    @GET
    @Path("/events/memory-snapshots/statuses")
    public Uni<MediaMemorySnapshotSyncStatusesResponse> memorySnapshotSyncStatuses(
            @QueryParam("limit") Integer limit) {
        return service.memorySnapshotSyncStatuses(limit);
    }

    @GET
    @Path("/events/memory-snapshots/ops")
    public Uni<MediaMemorySnapshotSyncOpsResponse> memorySnapshotSyncOps(
            @QueryParam("limit") Integer limit,
            @QueryParam("historyLimit") Integer historyLimit) {
        return service.memorySnapshotSyncOps(limit, historyLimit);
    }

    @GET
    @Path("/events/memory-snapshots/checkpoint")
    public Uni<MediaSyncCheckpointResponse> memorySnapshotCheckpoint(
            @QueryParam("consumerId") String consumerId) {
        return service.memorySnapshotCheckpoint(consumerId);
    }

    @PUT
    @Path("/events/memory-snapshots/checkpoint")
    public Uni<MediaSyncCheckpointResponse> updateMemorySnapshotCheckpoint(MediaSyncCheckpointRequest request) {
        return service.updateMemorySnapshotCheckpoint(request);
    }

    @GET
    @Path("/{mediaId}")
    public Uni<MediaResponse> get(@PathParam("mediaId") String mediaId) {
        return service.get(mediaId);
    }

    @GET
    @Path("/users/{ownerId}")
    public Uni<MediaListResponse> userMedia(@PathParam("ownerId") String ownerId) {
        return service.userMedia(ownerId);
    }

    @DELETE
    @Path("/{mediaId}")
    public Uni<Response> delete(
            @PathParam("mediaId") String mediaId,
            @QueryParam("ownerId") String ownerId) {
        return service.delete(mediaId, ownerId)
                .replaceWith(Response.noContent().build());
    }

    @PUT
    @Path("/{mediaId}/moderation")
    public Uni<MediaResponse> moderate(
            @PathParam("mediaId") String mediaId,
            ModerationUpdateRequest request) {
        return service.moderate(mediaId, request);
    }

    @GET
    @Path("/{mediaId}/moderation")
    public Uni<ModerationHistoryResponse> moderationHistory(
            @PathParam("mediaId") String mediaId,
            @QueryParam("reviewerId") String reviewerId) {
        return service.moderationHistory(mediaId, reviewerId);
    }
}
