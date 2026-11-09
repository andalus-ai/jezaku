package tech.kayys.jezaku.notifications;

import java.time.Instant;
import java.util.List;
import java.util.Map;

record NotificationRecord(
        String id,
        String userId,
        String type,
        String title,
        String body,
        String actionUrl,
        String severity,
        List<String> requestedChannels,
        List<String> deliveryChannels,
        Map<String, String> metadata,
        boolean muted,
        boolean read,
        Instant createdAt,
        Instant readAt,
        Instant expiresAt) {
    NotificationRecord markRead(Instant readAt) {
        return new NotificationRecord(id, userId, type, title, body, actionUrl, severity, requestedChannels,
                deliveryChannels, metadata, muted, true, createdAt, readAt, expiresAt);
    }
}
