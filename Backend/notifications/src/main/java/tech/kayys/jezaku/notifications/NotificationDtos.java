package tech.kayys.jezaku.notifications;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class NotificationDtos {
    private NotificationDtos() {
    }

    public record NotificationCreateRequest(
            String userId,
            String type,
            String title,
            String body,
            String actionUrl,
            String severity,
            List<String> channels,
            Map<String, String> metadata,
            Instant expiresAt) {
    }

    public record MessagingNotificationHandoffRequest(
            String deliveryId,
            String envelopeId,
            String threadId,
            String recipientUserId,
            String deliveryTarget,
            String eventType,
            Map<String, Object> payload) {
    }

    public record MessagingNotificationHandoffResponse(
            String deliveryId,
            String notificationId,
            String recipientUserId,
            String eventType,
            boolean duplicate,
            NotificationResponse notification) {
    }

    public record NotificationResponse(
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
    }

    public record NotificationInboxResponse(
            String userId,
            int unreadCount,
            int count,
            List<NotificationResponse> notifications) {
    }

    public record NotificationDeliveryEventResponse(
            String eventId,
            String notificationId,
            String userId,
            String channel,
            String status,
            String reason,
            Instant createdAt) {
    }

    public record NotificationDeliveryHistoryResponse(
            String notificationId,
            int count,
            List<NotificationDeliveryEventResponse> events) {
    }

    public record MarkReadRequest(List<String> notificationIds) {
    }

    public record NotificationPreferences(
            boolean inAppEnabled,
            boolean pushEnabled,
            boolean emailEnabled,
            String quietHoursStart,
            String quietHoursEnd,
            List<String> mutedTypes) {
    }

    public record DeviceRegistrationRequest(
            String userId,
            String platform,
            String pushToken,
            String deviceName,
            String locale,
            String appVersion) {
    }

    public record DeviceRegistrationResponse(
            String id,
            String userId,
            String platform,
            String pushToken,
            String deviceName,
            String locale,
            String appVersion,
            boolean enabled,
            Instant createdAt,
            Instant updatedAt) {
    }
}
