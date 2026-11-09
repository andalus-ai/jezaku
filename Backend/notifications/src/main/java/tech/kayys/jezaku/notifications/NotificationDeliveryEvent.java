package tech.kayys.jezaku.notifications;

import java.time.Instant;

record NotificationDeliveryEvent(
        String eventId,
        String notificationId,
        String userId,
        String channel,
        String status,
        String reason,
        Instant createdAt) {
}
