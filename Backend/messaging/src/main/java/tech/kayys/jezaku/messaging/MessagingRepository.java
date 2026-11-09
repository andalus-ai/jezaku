package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.List;

interface MessagingRepository {
    void saveThread(ThreadRecord thread);

    ThreadRecord findThreadById(String threadId);

    List<ThreadRecord> findAllThreads();

    void saveMessage(MessageRecord message);

    MessageRecord findMessageById(String messageId);

    List<MessageRecord> findAllMessages();

    void saveReadReceipt(String threadId, String userId, Instant lastReadAt);

    Instant findReadReceiptAt(String threadId, String userId);

    void saveMute(String threadId, String userId, boolean muted);

    boolean isMuted(String threadId, String userId);

    void saveActivity(MessagingActivityEvent activity);

    List<MessagingActivityEvent> findActivityByThreadId(String threadId);

    void saveOutboxEvent(MessagingOutboxEvent event);

    List<MessagingOutboxEvent> findOutboxEventsByStatus(String status);

    List<MessagingOutboxEvent> findDispatchableOutboxEvents(Instant now, int limit);

    List<MessagingOutboxEvent> findAllOutboxEvents();

    void saveFanoutEnvelope(MessagingFanoutEnvelope envelope);

    List<MessagingFanoutEnvelope> findDeliverableFanoutEnvelopes(Instant now, int limit);

    List<MessagingFanoutEnvelope> findFanoutEnvelopesByThreadId(String threadId);

    List<MessagingFanoutEnvelope> findFanoutEnvelopesByRecipient(String recipientUserId);

    List<MessagingFanoutEnvelope> findAllFanoutEnvelopes();

    void saveFanoutTargetDelivery(MessagingFanoutTargetDelivery delivery);

    MessagingFanoutTargetDelivery findFanoutTargetDeliveryById(String deliveryId);

    List<MessagingFanoutTargetDelivery> findFanoutTargetDeliveriesByRecipient(String recipientUserId);

    List<MessagingFanoutTargetDelivery> findFanoutTargetDeliveriesByRecipientAndTarget(
            String recipientUserId,
            String deliveryTarget);

    List<MessagingFanoutTargetDelivery> findReadyRealtimeTargetDeliveries(String recipientUserId, int limit);

    List<MessagingFanoutTargetDelivery> findAllFanoutTargetDeliveries();
}
