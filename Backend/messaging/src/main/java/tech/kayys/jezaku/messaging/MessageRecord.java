package tech.kayys.jezaku.messaging;

import tech.kayys.jezaku.messaging.MessagingDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

record MessageRecord(
        String messageId,
        String threadId,
        String senderId,
        String body,
        List<String> mediaIds,
        GeoPoint position,
        String status,
        Instant createdAt,
        Instant updatedAt) {
    MessageRecord withStatus(String status, Instant updatedAt) {
        return new MessageRecord(
                messageId,
                threadId,
                senderId,
                body,
                mediaIds,
                position,
                status,
                createdAt,
                updatedAt);
    }
}
