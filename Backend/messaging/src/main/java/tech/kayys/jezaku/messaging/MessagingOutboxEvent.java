package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.Map;

record MessagingOutboxEvent(
        String outboxId,
        String aggregateType,
        String aggregateId,
        String eventType,
        Map<String, Object> payload,
        String status,
        int attempts,
        Instant createdAt,
        Instant nextAttemptAt,
        Instant processedAt,
        Instant updatedAt,
        String lastError) {
    MessagingOutboxEvent {
        payload = Map.copyOf(payload);
    }

    MessagingOutboxEvent markDispatched(Instant processedAt) {
        return new MessagingOutboxEvent(
                outboxId,
                aggregateType,
                aggregateId,
                eventType,
                payload,
                MessagingSchema.OUTBOX_STATUS_DISPATCHED,
                attempts,
                createdAt,
                nextAttemptAt,
                processedAt,
                processedAt,
                "");
    }

    MessagingOutboxEvent markFailed(Instant updatedAt, Instant nextAttemptAt, String lastError) {
        return new MessagingOutboxEvent(
                outboxId,
                aggregateType,
                aggregateId,
                eventType,
                payload,
                MessagingSchema.OUTBOX_STATUS_FAILED,
                attempts + 1,
                createdAt,
                nextAttemptAt,
                null,
                updatedAt,
                lastError);
    }

    MessagingOutboxEvent requeueForRetry(Instant retriedAt) {
        return new MessagingOutboxEvent(
                outboxId,
                aggregateType,
                aggregateId,
                eventType,
                payload,
                MessagingSchema.OUTBOX_STATUS_PENDING,
                attempts,
                createdAt,
                retriedAt,
                null,
                retriedAt,
                "");
    }
}
