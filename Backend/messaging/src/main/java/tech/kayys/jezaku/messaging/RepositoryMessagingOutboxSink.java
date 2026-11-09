package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@ApplicationScoped
public class RepositoryMessagingOutboxSink implements MessagingOutboxSink {
    @Inject
    MessagingRepository repository;

    @Override
    public void dispatch(MessagingOutboxEvent event) {
        if (!MessagingSchema.OUTBOX_EVENT_TYPES.contains(event.eventType())) {
            throw new IllegalArgumentException("Unsupported messaging outbox event type: " + event.eventType());
        }
        ThreadRecord thread = repository.findThreadById(event.aggregateId());
        if (thread == null) {
            throw new IllegalStateException("Thread not found for messaging fanout: " + event.aggregateId());
        }
        String actorUserId = payloadText(event.payload(), "actorUserId");
        List<String> recipients = thread.participantIds().stream()
                .filter(userId -> !userId.equals(actorUserId))
                .sorted()
                .toList();
        for (String recipientUserId : recipients) {
            repository.saveFanoutEnvelope(toEnvelope(event, recipientUserId));
        }
    }

    private MessagingFanoutEnvelope toEnvelope(MessagingOutboxEvent event, String recipientUserId) {
        return new MessagingFanoutEnvelope(
                "messaging_fanout_" + UUID.randomUUID(),
                event.outboxId(),
                event.aggregateId(),
                recipientUserId,
                event.eventType(),
                deliveryTargets(event.eventType()),
                payload(event),
                MessagingSchema.FANOUT_STATUS_QUEUED,
                0,
                createdAt(event),
                createdAt(event),
                null,
                createdAt(event),
                "");
    }

    private List<String> deliveryTargets(String eventType) {
        return switch (eventType) {
            case MessagingSchema.EVENT_THREAD_CREATED, MessagingSchema.EVENT_MESSAGE_SENT ->
                    List.of(MessagingSchema.FANOUT_TARGET_REALTIME, MessagingSchema.FANOUT_TARGET_NOTIFICATION);
            case MessagingSchema.EVENT_MESSAGE_DELETED,
                    MessagingSchema.EVENT_THREAD_READ,
                    MessagingSchema.EVENT_THREAD_MUTED,
                    MessagingSchema.EVENT_THREAD_UNMUTED ->
                    List.of(MessagingSchema.FANOUT_TARGET_REALTIME);
            default -> throw new IllegalArgumentException("Unsupported messaging outbox event type: " + eventType);
        };
    }

    private Map<String, Object> payload(MessagingOutboxEvent event) {
        Map<String, Object> payload = new LinkedHashMap<>(event.payload());
        payload.put("outboxId", event.outboxId());
        payload.put("eventType", event.eventType());
        return Map.copyOf(payload);
    }

    private Instant createdAt(MessagingOutboxEvent event) {
        return event.updatedAt() == null ? event.createdAt() : event.updatedAt();
    }

    private String payloadText(Map<String, Object> payload, String key) {
        Object value = payload.get(key);
        return value == null ? "" : value.toString();
    }
}
