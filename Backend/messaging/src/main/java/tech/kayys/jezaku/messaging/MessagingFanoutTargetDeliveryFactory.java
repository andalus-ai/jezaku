package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

final class MessagingFanoutTargetDeliveryFactory {
    private MessagingFanoutTargetDeliveryFactory() {
    }

    static MessagingFanoutTargetDelivery from(
            MessagingFanoutEnvelope envelope,
            String deliveryTarget,
            Instant createdAt) {
        Map<String, Object> payload = new LinkedHashMap<>(envelope.payload());
        payload.put("envelopeId", envelope.envelopeId());
        payload.put("outboxId", envelope.outboxId());
        payload.put("threadId", envelope.threadId());
        payload.put("recipientUserId", envelope.recipientUserId());
        payload.put("eventType", envelope.eventType());
        payload.put("deliveryTarget", deliveryTarget);
        return new MessagingFanoutTargetDelivery(
                deliveryId(envelope, deliveryTarget),
                envelope.envelopeId(),
                envelope.threadId(),
                envelope.recipientUserId(),
                deliveryTarget,
                envelope.eventType(),
                Map.copyOf(payload),
                MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY,
                createdAt,
                null,
                createdAt);
    }

    private static String deliveryId(MessagingFanoutEnvelope envelope, String deliveryTarget) {
        return envelope.envelopeId() + ":" + deliveryTarget;
    }
}
