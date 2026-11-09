package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class MessagingDtos {
    private MessagingDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record ThreadCreateRequest(
            String creatorId,
            String threadType,
            String targetType,
            String targetId,
            String title,
            List<String> participantIds) {
    }

    public record ThreadResponse(
            String threadId,
            String threadType,
            String targetType,
            String targetId,
            String title,
            List<String> participantIds,
            String status,
            String lastMessagePreview,
            int unreadCount,
            boolean muted,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record ThreadListResponse(String userId, int count, List<ThreadResponse> threads) {
    }

    public record MessageCreateRequest(
            String senderId,
            String body,
            List<String> mediaIds,
            GeoPoint position) {
    }

    public record MessageResponse(
            String messageId,
            String threadId,
            String senderId,
            String body,
            List<String> mediaIds,
            GeoPoint position,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record MessageListResponse(String threadId, int count, List<MessageResponse> messages) {
    }

    public record ThreadActivityResponse(
            String activityId,
            String threadId,
            String actorUserId,
            String activityType,
            String targetId,
            String detail,
            Instant createdAt) {
    }

    public record ThreadActivityHistoryResponse(String threadId, int count, List<ThreadActivityResponse> activity) {
    }

    public record ReadReceiptRequest(String userId) {
    }

    public record ReadReceiptResponse(String threadId, String userId, Instant lastReadAt, int unreadCount) {
    }

    public record MuteRequest(String userId, boolean muted) {
    }

    public record MuteResponse(String threadId, String userId, boolean muted, Instant updatedAt) {
    }

    public record RealtimeEventResponse(
            String deliveryId,
            String envelopeId,
            String threadId,
            String recipientUserId,
            String eventType,
            Map<String, Object> payload,
            Instant createdAt) {
    }

    public record RealtimeEventListResponse(String userId, int count, List<RealtimeEventResponse> events) {
    }

    public record RealtimeAckRequest(List<String> deliveryIds) {
    }

    public record RealtimeAckResponse(String userId, int acknowledgedCount, Instant acknowledgedAt) {
    }

    public record PipelineDrainResponse(
            int outboxScanned,
            int outboxDispatched,
            int outboxFailed,
            int fanoutScanned,
            int fanoutDelivered,
            int fanoutFailed,
            Instant drainedAt) {
    }

    public record PipelineStatusResponse(
            int outboxPending,
            int outboxDispatched,
            int outboxFailed,
            int fanoutQueued,
            int fanoutDelivered,
            int fanoutFailed,
            int realtimeReady,
            int realtimeAcknowledged,
            int notificationReady,
            int notificationAcknowledged,
            Instant checkedAt) {
    }

    public record PipelineOutboxFailureResponse(
            String outboxId,
            String aggregateType,
            String aggregateId,
            String eventType,
            int attempts,
            Instant createdAt,
            Instant nextAttemptAt,
            Instant updatedAt,
            String lastError) {
    }

    public record PipelineFanoutFailureResponse(
            String envelopeId,
            String outboxId,
            String threadId,
            String recipientUserId,
            String eventType,
            List<String> deliveryTargets,
            int attempts,
            Instant createdAt,
            Instant nextAttemptAt,
            Instant updatedAt,
            String lastError) {
    }

    public record PipelineFailureListResponse(
            int outboxFailedAvailable,
            int outboxReturned,
            int fanoutFailedAvailable,
            int fanoutReturned,
            List<PipelineOutboxFailureResponse> outboxFailures,
            List<PipelineFanoutFailureResponse> fanoutFailures,
            Instant checkedAt) {
    }

    public record PipelineRetryFailedResponse(
            int outboxFailedAvailable,
            int outboxRetried,
            int fanoutFailedAvailable,
            int fanoutRetried,
            Instant retriedAt) {
    }

    public record PipelineAutoDrainStatusResponse(
            boolean enabled,
            boolean running,
            long intervalMillis,
            int batchSize,
            Instant lastAttemptAt,
            Instant lastSuccessAt,
            Instant lastFailureAt,
            String lastFailureMessage,
            PipelineDrainResponse lastDrain) {
    }

    public record OpsAuditEventResponse(
            String auditId,
            String action,
            String actor,
            String requestId,
            String outcome,
            Map<String, Object> details,
            Instant occurredAt) {
    }

    public record OpsAuditListResponse(
            int total,
            int count,
            List<OpsAuditEventResponse> events,
            Instant checkedAt) {
    }

    public record OpsAuditCountResponse(String key, int count) {
    }

    public record OpsAuditSummaryResponse(
            int total,
            List<OpsAuditCountResponse> byAction,
            List<OpsAuditCountResponse> byActor,
            List<OpsAuditCountResponse> byOutcome,
            Instant checkedAt) {
    }
}
