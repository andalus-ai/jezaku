package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.List;
import java.util.Map;

record MessagingFanoutEnvelope(
        String envelopeId,
        String outboxId,
        String threadId,
        String recipientUserId,
        String eventType,
        List<String> deliveryTargets,
        Map<String, Object> payload,
        String status,
        int attempts,
        Instant createdAt,
        Instant nextAttemptAt,
        Instant deliveredAt,
        Instant updatedAt,
        String lastError) {
    MessagingFanoutEnvelope {
        deliveryTargets = List.copyOf(deliveryTargets);
        payload = Map.copyOf(payload);
    }

    MessagingFanoutEnvelope markDelivered(Instant deliveredAt) {
        return new MessagingFanoutEnvelope(
                envelopeId,
                outboxId,
                threadId,
                recipientUserId,
                eventType,
                deliveryTargets,
                payload,
                MessagingSchema.FANOUT_STATUS_DELIVERED,
                attempts,
                createdAt,
                nextAttemptAt,
                deliveredAt,
                deliveredAt,
                "");
    }

    MessagingFanoutEnvelope markFailed(Instant updatedAt, Instant nextAttemptAt, String lastError) {
        return new MessagingFanoutEnvelope(
                envelopeId,
                outboxId,
                threadId,
                recipientUserId,
                eventType,
                deliveryTargets,
                payload,
                MessagingSchema.FANOUT_STATUS_FAILED,
                attempts + 1,
                createdAt,
                nextAttemptAt,
                null,
                updatedAt,
                lastError);
    }

    MessagingFanoutEnvelope requeueForRetry(Instant retriedAt) {
        return new MessagingFanoutEnvelope(
                envelopeId,
                outboxId,
                threadId,
                recipientUserId,
                eventType,
                deliveryTargets,
                payload,
                MessagingSchema.FANOUT_STATUS_QUEUED,
                attempts,
                createdAt,
                retriedAt,
                null,
                retriedAt,
                "");
    }
}
