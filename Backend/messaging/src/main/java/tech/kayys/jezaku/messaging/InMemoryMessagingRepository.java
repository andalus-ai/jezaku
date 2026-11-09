package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class InMemoryMessagingRepository implements MessagingRepository {
    private final Map<String, ThreadRecord> threads = new ConcurrentHashMap<>();
    private final Map<String, MessageRecord> messages = new ConcurrentHashMap<>();
    private final Map<String, Instant> readReceipts = new ConcurrentHashMap<>();
    private final Map<String, Boolean> mutes = new ConcurrentHashMap<>();
    private final Map<String, List<MessagingActivityEvent>> activity = new ConcurrentHashMap<>();
    private final Map<String, MessagingOutboxEvent> outbox = new ConcurrentHashMap<>();
    private final Map<String, MessagingFanoutEnvelope> fanout = new ConcurrentHashMap<>();
    private final Map<String, MessagingFanoutTargetDelivery> targetDeliveries = new ConcurrentHashMap<>();

    @Override
    public void saveThread(ThreadRecord thread) {
        threads.put(thread.threadId(), thread);
    }

    @Override
    public ThreadRecord findThreadById(String threadId) {
        return threads.get(threadId);
    }

    @Override
    public List<ThreadRecord> findAllThreads() {
        return List.copyOf(threads.values());
    }

    @Override
    public void saveMessage(MessageRecord message) {
        messages.put(message.messageId(), message);
    }

    @Override
    public MessageRecord findMessageById(String messageId) {
        return messages.get(messageId);
    }

    @Override
    public List<MessageRecord> findAllMessages() {
        return List.copyOf(messages.values());
    }

    @Override
    public void saveReadReceipt(String threadId, String userId, Instant lastReadAt) {
        readReceipts.put(participantKey(threadId, userId), lastReadAt);
    }

    @Override
    public Instant findReadReceiptAt(String threadId, String userId) {
        return readReceipts.get(participantKey(threadId, userId));
    }

    @Override
    public void saveMute(String threadId, String userId, boolean muted) {
        mutes.put(participantKey(threadId, userId), muted);
    }

    @Override
    public boolean isMuted(String threadId, String userId) {
        return mutes.getOrDefault(participantKey(threadId, userId), false);
    }

    @Override
    public void saveActivity(MessagingActivityEvent event) {
        activity.compute(event.threadId(), (threadId, events) -> {
            List<MessagingActivityEvent> updated = new ArrayList<>();
            if (events != null) {
                updated.addAll(events);
            }
            updated.add(event);
            return List.copyOf(updated);
        });
    }

    @Override
    public List<MessagingActivityEvent> findActivityByThreadId(String threadId) {
        return List.copyOf(activity.getOrDefault(threadId, List.of()));
    }

    @Override
    public void saveOutboxEvent(MessagingOutboxEvent event) {
        outbox.put(event.outboxId(), event);
    }

    @Override
    public List<MessagingOutboxEvent> findOutboxEventsByStatus(String status) {
        return outbox.values().stream()
                .filter(event -> event.status().equals(status))
                .toList();
    }

    @Override
    public List<MessagingOutboxEvent> findDispatchableOutboxEvents(Instant now, int limit) {
        if (limit <= 0) {
            return List.of();
        }
        return outbox.values().stream()
                .filter(event -> MessagingSchema.OUTBOX_STATUS_PENDING.equals(event.status())
                        || MessagingSchema.OUTBOX_STATUS_FAILED.equals(event.status()))
                .filter(event -> !event.nextAttemptAt().isAfter(now))
                .sorted(Comparator.comparing(MessagingOutboxEvent::nextAttemptAt)
                        .thenComparing(MessagingOutboxEvent::createdAt)
                        .thenComparing(MessagingOutboxEvent::outboxId))
                .limit(limit)
                .toList();
    }

    @Override
    public List<MessagingOutboxEvent> findAllOutboxEvents() {
        return outbox.values().stream()
                .sorted(Comparator.comparing(MessagingOutboxEvent::createdAt)
                        .thenComparing(MessagingOutboxEvent::outboxId))
                .toList();
    }

    @Override
    public void saveFanoutEnvelope(MessagingFanoutEnvelope envelope) {
        fanout.put(envelope.envelopeId(), envelope);
    }

    @Override
    public List<MessagingFanoutEnvelope> findDeliverableFanoutEnvelopes(Instant now, int limit) {
        if (limit <= 0) {
            return List.of();
        }
        return fanout.values().stream()
                .filter(envelope -> MessagingSchema.FANOUT_STATUS_QUEUED.equals(envelope.status())
                        || MessagingSchema.FANOUT_STATUS_FAILED.equals(envelope.status()))
                .filter(envelope -> !envelope.nextAttemptAt().isAfter(now))
                .sorted(Comparator.comparing(MessagingFanoutEnvelope::nextAttemptAt)
                        .thenComparing(MessagingFanoutEnvelope::createdAt)
                        .thenComparing(MessagingFanoutEnvelope::recipientUserId)
                        .thenComparing(MessagingFanoutEnvelope::envelopeId))
                .limit(limit)
                .toList();
    }

    @Override
    public List<MessagingFanoutEnvelope> findFanoutEnvelopesByThreadId(String threadId) {
        return fanout.values().stream()
                .filter(envelope -> envelope.threadId().equals(threadId))
                .sorted(Comparator.comparing(MessagingFanoutEnvelope::createdAt)
                        .thenComparing(MessagingFanoutEnvelope::recipientUserId)
                        .thenComparing(MessagingFanoutEnvelope::envelopeId))
                .toList();
    }

    @Override
    public List<MessagingFanoutEnvelope> findFanoutEnvelopesByRecipient(String recipientUserId) {
        return fanout.values().stream()
                .filter(envelope -> envelope.recipientUserId().equals(recipientUserId))
                .sorted(Comparator.comparing(MessagingFanoutEnvelope::createdAt)
                        .thenComparing(MessagingFanoutEnvelope::envelopeId))
                .toList();
    }

    @Override
    public List<MessagingFanoutEnvelope> findAllFanoutEnvelopes() {
        return fanout.values().stream()
                .sorted(Comparator.comparing(MessagingFanoutEnvelope::createdAt)
                        .thenComparing(MessagingFanoutEnvelope::recipientUserId)
                        .thenComparing(MessagingFanoutEnvelope::envelopeId))
                .toList();
    }

    @Override
    public void saveFanoutTargetDelivery(MessagingFanoutTargetDelivery delivery) {
        targetDeliveries.compute(delivery.deliveryId(), (deliveryId, existing) -> {
            if (existing == null) {
                return delivery;
            }
            if (MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED.equals(existing.status())
                    && MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY.equals(delivery.status())) {
                return existing;
            }
            return delivery;
        });
    }

    @Override
    public MessagingFanoutTargetDelivery findFanoutTargetDeliveryById(String deliveryId) {
        return targetDeliveries.get(deliveryId);
    }

    @Override
    public List<MessagingFanoutTargetDelivery> findFanoutTargetDeliveriesByRecipient(String recipientUserId) {
        return targetDeliveries.values().stream()
                .filter(delivery -> delivery.recipientUserId().equals(recipientUserId))
                .sorted(Comparator.comparing(MessagingFanoutTargetDelivery::createdAt)
                        .thenComparing(MessagingFanoutTargetDelivery::deliveryTarget)
                        .thenComparing(MessagingFanoutTargetDelivery::deliveryId))
                .toList();
    }

    @Override
    public List<MessagingFanoutTargetDelivery> findFanoutTargetDeliveriesByRecipientAndTarget(
            String recipientUserId,
            String deliveryTarget) {
        return targetDeliveries.values().stream()
                .filter(delivery -> delivery.recipientUserId().equals(recipientUserId))
                .filter(delivery -> delivery.deliveryTarget().equals(deliveryTarget))
                .sorted(Comparator.comparing(MessagingFanoutTargetDelivery::createdAt)
                        .thenComparing(MessagingFanoutTargetDelivery::deliveryId))
                .toList();
    }

    @Override
    public List<MessagingFanoutTargetDelivery> findReadyRealtimeTargetDeliveries(String recipientUserId, int limit) {
        if (limit <= 0) {
            return List.of();
        }
        return targetDeliveries.values().stream()
                .filter(delivery -> delivery.recipientUserId().equals(recipientUserId))
                .filter(delivery -> MessagingSchema.FANOUT_TARGET_REALTIME.equals(delivery.deliveryTarget()))
                .filter(delivery -> MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY.equals(delivery.status()))
                .sorted(Comparator.comparing(MessagingFanoutTargetDelivery::createdAt)
                        .thenComparing(MessagingFanoutTargetDelivery::deliveryId))
                .limit(limit)
                .toList();
    }

    @Override
    public List<MessagingFanoutTargetDelivery> findAllFanoutTargetDeliveries() {
        return targetDeliveries.values().stream()
                .sorted(Comparator.comparing(MessagingFanoutTargetDelivery::createdAt)
                        .thenComparing(MessagingFanoutTargetDelivery::recipientUserId)
                        .thenComparing(MessagingFanoutTargetDelivery::deliveryTarget)
                        .thenComparing(MessagingFanoutTargetDelivery::deliveryId))
                .toList();
    }

    private String participantKey(String threadId, String userId) {
        return threadId + "|" + userId;
    }
}
