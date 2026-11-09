package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.Map;

record MessagingFanoutTargetDelivery(
        String deliveryId,
        String envelopeId,
        String threadId,
        String recipientUserId,
        String deliveryTarget,
        String eventType,
        Map<String, Object> payload,
        String status,
        Instant createdAt,
        Instant acknowledgedAt,
        Instant updatedAt) {
    MessagingFanoutTargetDelivery {
        payload = Map.copyOf(payload);
    }

    MessagingFanoutTargetDelivery markAcknowledged(Instant acknowledgedAt) {
        return new MessagingFanoutTargetDelivery(
                deliveryId,
                envelopeId,
                threadId,
                recipientUserId,
                deliveryTarget,
                eventType,
                payload,
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED,
                createdAt,
                acknowledgedAt,
                acknowledgedAt);
    }
}
