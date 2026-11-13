package tech.kayys.jezaku.messaging;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageCreateRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.MuteRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.MuteResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.OpsAuditSummaryResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineAutoDrainStatusResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineDrainResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineFailureListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineRetryFailedResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.PipelineStatusResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeAckRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeAckResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeEventListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ReadReceiptRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.ReadReceiptResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadCreateRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadActivityHistoryResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadResponse;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedUser;
import tech.kayys.jezaku.http.RequestIdFilter;

import java.time.Instant;
import java.time.format.DateTimeParseException;

@Path("/messaging")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class MessagingResource {
    @Inject
    MessagingService service;

    @Inject
    MessagingPipelineService pipelineService;

    @Inject
    MessagingPipelineAutoDrainer autoDrainer;

    @Inject
    MessagingOpsGuard opsGuard;

    @Inject
    MessagingOpsAuditLog opsAudit;

    @Context
    ContainerRequestContext requestContext;

    private void self(String userId) {
        AuthContext.requireSelf(requestContext, userId);
    }

    /**
     * The viewer to check thread membership against. A caller that names a viewer must be that user; a caller that
     * names none is checked as themselves when authenticated, so omitting the parameter never skips the check.
     */
    private String viewer(String claimedViewerId) {
        if (claimedViewerId != null && !claimedViewerId.isBlank()) {
            self(claimedViewerId);
            return claimedViewerId;
        }
        return AuthContext.user(requestContext).map(AuthenticatedUser::userId).orElse(claimedViewerId);
    }

    @POST
    @Path("/threads")
    public Uni<Response> createThread(ThreadCreateRequest request) {
        self(request == null ? null : request.creatorId());
        return service.createThread(request)
                .map(thread -> Response.status(Response.Status.CREATED).entity(thread).build());
    }

    @GET
    @Path("/users/{userId}/threads")
    public Uni<ThreadListResponse> userThreads(@PathParam("userId") String userId) {
        self(userId);
        return service.userThreads(userId);
    }

    @GET
    @Path("/threads/{threadId}")
    public Uni<ThreadResponse> thread(
            @PathParam("threadId") String threadId,
            @QueryParam("viewerId") String viewerId) {
        return service.thread(threadId, viewer(viewerId));
    }

    @GET
    @Path("/contexts/{targetType}/{targetId}/thread")
    public Uni<ThreadResponse> contextThread(
            @PathParam("targetType") String targetType,
            @PathParam("targetId") String targetId,
            @QueryParam("viewerId") String viewerId) {
        return service.contextThread(targetType, targetId, viewer(viewerId));
    }

    @POST
    @Path("/threads/{threadId}/messages")
    public Uni<Response> sendMessage(
            @PathParam("threadId") String threadId,
            MessageCreateRequest request) {
        self(request == null ? null : request.senderId());
        return service.sendMessage(threadId, request)
                .map(message -> Response.status(Response.Status.CREATED).entity(message).build());
    }

    @GET
    @Path("/threads/{threadId}/messages")
    public Uni<MessageListResponse> messages(@PathParam("threadId") String threadId) {
        return service.messages(threadId, viewer(null));
    }

    @GET
    @Path("/threads/{threadId}/activity")
    public Uni<ThreadActivityHistoryResponse> activity(
            @PathParam("threadId") String threadId,
            @QueryParam("viewerId") String viewerId) {
        return service.activity(threadId, viewer(viewerId));
    }

    @DELETE
    @Path("/threads/{threadId}/messages/{messageId}")
    public Uni<Response> deleteMessage(
            @PathParam("threadId") String threadId,
            @PathParam("messageId") String messageId,
            @QueryParam("userId") String userId) {
        self(userId);
        return service.deleteMessage(threadId, messageId, userId)
                .replaceWith(Response.noContent().build());
    }

    @POST
    @Path("/threads/{threadId}/read")
    public Uni<ReadReceiptResponse> markRead(
            @PathParam("threadId") String threadId,
            ReadReceiptRequest request) {
        self(request == null ? null : request.userId());
        return service.markRead(threadId, request);
    }

    @POST
    @Path("/threads/{threadId}/mute")
    public Uni<MuteResponse> mute(
            @PathParam("threadId") String threadId,
            MuteRequest request) {
        self(request == null ? null : request.userId());
        return service.mute(threadId, request);
    }

    @GET
    @Path("/realtime/users/{userId}/events")
    public Uni<RealtimeEventListResponse> realtimeEvents(
            @PathParam("userId") String userId,
            @QueryParam("limit") Integer limit) {
        self(userId);
        return service.realtimeEvents(userId, limit);
    }

    @POST
    @Path("/realtime/users/{userId}/ack")
    public Uni<RealtimeAckResponse> acknowledgeRealtimeEvents(
            @PathParam("userId") String userId,
            RealtimeAckRequest request) {
        self(userId);
        return service.acknowledgeRealtimeEvents(userId, request);
    }

    @POST
    @Path("/ops/pipeline/drain")
    public Uni<PipelineDrainResponse> drainPipeline(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken,
            @HeaderParam(MessagingOpsAuditLog.OPS_ACTOR_HEADER) String opsActor,
            @HeaderParam(RequestIdFilter.HEADER) String requestId,
            @QueryParam("batchSize") Integer batchSize) {
        opsGuard.requireAccess(opsToken);
        return pipelineService.drain(batchSize)
                .invoke(response -> opsAudit.recordPipelineDrain(opsActor, requestId, batchSize, response))
                .onFailure().invoke(failure -> opsAudit.recordFailure(
                        MessagingOpsAuditLog.ACTION_PIPELINE_DRAIN,
                        opsActor,
                        requestId,
                        failure));
    }

    @GET
    @Path("/ops/pipeline/status")
    public Uni<PipelineStatusResponse> pipelineStatus(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken) {
        opsGuard.requireAccess(opsToken);
        return pipelineService.status();
    }

    @GET
    @Path("/ops/pipeline/failures")
    public Uni<PipelineFailureListResponse> pipelineFailures(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken,
            @HeaderParam(MessagingOpsAuditLog.OPS_ACTOR_HEADER) String opsActor,
            @HeaderParam(RequestIdFilter.HEADER) String requestId,
            @QueryParam("limit") Integer limit) {
        opsGuard.requireAccess(opsToken);
        return pipelineService.failures(limit)
                .invoke(response -> opsAudit.recordPipelineFailures(opsActor, requestId, limit, response))
                .onFailure().invoke(failure -> opsAudit.recordFailure(
                        MessagingOpsAuditLog.ACTION_PIPELINE_FAILURES,
                        opsActor,
                        requestId,
                        failure));
    }

    @POST
    @Path("/ops/pipeline/retry-failed")
    public Uni<PipelineRetryFailedResponse> retryFailedPipelineWork(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken,
            @HeaderParam(MessagingOpsAuditLog.OPS_ACTOR_HEADER) String opsActor,
            @HeaderParam(RequestIdFilter.HEADER) String requestId,
            @QueryParam("limit") Integer limit) {
        opsGuard.requireAccess(opsToken);
        return pipelineService.retryFailed(limit)
                .invoke(response -> opsAudit.recordPipelineRetryFailed(opsActor, requestId, limit, response))
                .onFailure().invoke(failure -> opsAudit.recordFailure(
                        MessagingOpsAuditLog.ACTION_PIPELINE_RETRY_FAILED,
                        opsActor,
                        requestId,
                        failure));
    }

    @GET
    @Path("/ops/pipeline/auto-drain")
    public Uni<PipelineAutoDrainStatusResponse> autoDrainStatus(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken) {
        opsGuard.requireAccess(opsToken);
        return Uni.createFrom().item(autoDrainer::status);
    }

    @GET
    @Path("/ops/audit")
    public Uni<OpsAuditListResponse> opsAudit(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken,
            @QueryParam("limit") Integer limit,
            @QueryParam("action") String action,
            @QueryParam("actor") String actor,
            @QueryParam("outcome") String outcome,
            @QueryParam("requestId") String requestId,
            @QueryParam("since") String since,
            @QueryParam("until") String until) {
        opsGuard.requireAccess(opsToken);
        AuditTimeWindow window = auditTimeWindow(since, until);
        return Uni.createFrom().item(() -> opsAudit.list(
                limit,
                action,
                actor,
                outcome,
                requestId,
                window.since(),
                window.until()));
    }

    @GET
    @Path("/ops/audit/summary")
    public Uni<OpsAuditSummaryResponse> opsAuditSummary(
            @HeaderParam(MessagingOpsGuard.OPS_TOKEN_HEADER) String opsToken,
            @QueryParam("action") String action,
            @QueryParam("actor") String actor,
            @QueryParam("outcome") String outcome,
            @QueryParam("requestId") String requestId,
            @QueryParam("since") String since,
            @QueryParam("until") String until) {
        opsGuard.requireAccess(opsToken);
        AuditTimeWindow window = auditTimeWindow(since, until);
        return Uni.createFrom().item(() -> opsAudit.summary(
                action,
                actor,
                outcome,
                requestId,
                window.since(),
                window.until()));
    }

    AuditTimeWindow auditTimeWindow(String since, String until) {
        Instant sinceAt = parseAuditInstant("since", since);
        Instant untilAt = parseAuditInstant("until", until);
        if (sinceAt != null && untilAt != null && sinceAt.isAfter(untilAt)) {
            throw new BadRequestException("since must not be after until");
        }
        return new AuditTimeWindow(sinceAt, untilAt);
    }

    Instant parseAuditInstant(String field, String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return Instant.parse(value.trim());
        } catch (DateTimeParseException exception) {
            throw new BadRequestException(field + " must be an ISO-8601 instant");
        }
    }

    record AuditTimeWindow(Instant since, Instant until) {
    }
}
