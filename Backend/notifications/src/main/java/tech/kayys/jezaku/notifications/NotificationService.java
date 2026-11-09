package tech.kayys.jezaku.notifications;

import io.smallrye.mutiny.Uni;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.notifications.NotificationDtos.DeviceRegistrationRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.DeviceRegistrationResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.MarkReadRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.MessagingNotificationHandoffRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.MessagingNotificationHandoffResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationCreateRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationDeliveryEventResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationDeliveryHistoryResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationInboxResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationPreferences;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static tech.kayys.jezaku.taxonomy.JezakuChoices.PLATFORMS;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.NOTIFICATION_CHANNELS;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.NOTIFICATION_SEVERITIES;
import static tech.kayys.jezaku.validation.RequestParams.clampInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TimeParams.normalizeQuietHour;

@ApplicationScoped
public class NotificationService {
    private static final String MESSAGING_DELIVERY_TARGET = "notification";
    private static final String EVENT_THREAD_CREATED = "messaging.thread.created";
    private static final String EVENT_MESSAGE_SENT = "messaging.message.sent";
    private static final String SOURCE_MESSAGING_FANOUT = "messaging_fanout";
    private static final Set<String> TYPES = Set.of(
            "friend_request",
            "trail_invite",
            "nearby_memory",
            "safety_alert",
            "parental_notice",
            "messaging",
            "system");

    @Inject
    NotificationRepository repository;

    @PostConstruct
    void initialize() {
        seed();
    }

    public Uni<NotificationResponse> create(NotificationCreateRequest request) {
        return Uni.createFrom().item(() -> createNotification(request));
    }

    public Uni<MessagingNotificationHandoffResponse> ingestMessagingHandoff(
            MessagingNotificationHandoffRequest request) {
        return Uni.createFrom().item(() -> {
            validateMessagingHandoff(request);
            String deliveryId = requireText(request.deliveryId(), "deliveryId");
            String recipientUserId = requireText(request.recipientUserId(), "recipientUserId");
            String eventType = requireText(request.eventType(), "eventType");
            NotificationRecord existing = findBySourceDeliveryId(deliveryId);
            if (existing != null) {
                return new MessagingNotificationHandoffResponse(
                        deliveryId,
                        existing.id(),
                        existing.userId(),
                        eventType,
                        true,
                        toResponse(existing));
            }

            NotificationResponse notification = createNotification(toMessagingNotificationRequest(request));
            return new MessagingNotificationHandoffResponse(
                    deliveryId,
                    notification.id(),
                    notification.userId(),
                    eventType,
                    false,
                    notification);
        });
    }

    public Uni<NotificationInboxResponse> inbox(String userId, Boolean unreadOnly, Integer limit) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            boolean onlyUnread = Boolean.TRUE.equals(unreadOnly);
            int max = clampInt(limit, 50, 1, 100);
            return buildInbox(normalizedUserId, onlyUnread, max);
        });
    }

    public Uni<NotificationInboxResponse> markRead(String userId, MarkReadRequest request) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<String> ids = request == null ? List.of() : request.notificationIds();
            Instant now = Instant.now();
            repository.findAllNotifications().stream()
                    .filter(notification -> notification.userId().equals(normalizedUserId))
                    .filter(notification -> ids == null || ids.isEmpty() || ids.contains(notification.id()))
                    .forEach(notification -> repository.saveNotification(notification.markRead(now)));
            return buildInbox(normalizedUserId, false, 50);
        });
    }

    public Uni<NotificationDeliveryHistoryResponse> deliveryHistory(String userId, String notificationId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            String normalizedNotificationId = requireText(notificationId, "notificationId");
            NotificationRecord notification = repository.findNotificationById(normalizedNotificationId);
            if (notification == null || !notification.userId().equals(normalizedUserId)) {
                throw new NotFoundException("Notification not found: " + normalizedNotificationId);
            }
            List<NotificationDeliveryEventResponse> events = repository
                    .findDeliveryEventsByNotificationId(normalizedNotificationId).stream()
                    .sorted(Comparator.comparing(NotificationDeliveryEvent::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new NotificationDeliveryHistoryResponse(normalizedNotificationId, events.size(), events);
        });
    }

    public Uni<Void> delete(String userId, String notificationId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            String normalizedNotificationId = requireText(notificationId, "notificationId");
            NotificationRecord notification = repository.findNotificationById(normalizedNotificationId);
            if (notification == null || !notification.userId().equals(normalizedUserId)) {
                throw new NotFoundException("Notification not found: " + normalizedNotificationId);
            }
            repository.deleteNotificationById(normalizedNotificationId);
            return null;
        });
    }

    public Uni<NotificationPreferences> preferences(String userId) {
        return Uni.createFrom().item(() -> preferencesFor(requireText(userId, "userId")));
    }

    public Uni<NotificationPreferences> updatePreferences(String userId, NotificationPreferences request) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            NotificationPreferences normalized = new NotificationPreferences(
                    request.inAppEnabled(),
                    request.pushEnabled(),
                    request.emailEnabled(),
                    normalizeQuietHour(request.quietHoursStart(), "22:00", "quietHoursStart"),
                    normalizeQuietHour(request.quietHoursEnd(), "06:00", "quietHoursEnd"),
                    normalizeMutedTypes(request.mutedTypes()));
            repository.savePreferences(normalizedUserId, normalized);
            return normalized;
        });
    }

    public Uni<DeviceRegistrationResponse> registerDevice(DeviceRegistrationRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String userId = requireText(request.userId(), "userId");
            String pushToken = requireText(request.pushToken(), "pushToken");
            String platform = normalizePlatform(request.platform());
            Instant now = Instant.now();
            DeviceRecord existing = repository.findAllDevices().stream()
                    .filter(device -> device.userId().equals(userId))
                    .filter(device -> device.pushToken().equals(pushToken))
                    .findFirst()
                    .orElse(null);
            DeviceRecord saved = new DeviceRecord(
                    existing == null ? "device_" + UUID.randomUUID() : existing.id(),
                    userId,
                    platform,
                    pushToken,
                    optionalTrim(request.deviceName(), platform),
                    optionalTrim(request.locale(), "en"),
                    optionalTrim(request.appVersion(), ""),
                    true,
                    existing == null ? now : existing.createdAt(),
                    now);
            repository.saveDevice(saved);
            return toResponse(saved);
        });
    }

    public Uni<List<DeviceRegistrationResponse>> devices(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            return repository.findAllDevices().stream()
                    .filter(device -> device.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(DeviceRecord::updatedAt).reversed())
                    .map(this::toResponse)
                    .toList();
        });
    }

    public Uni<Void> disableDevice(String userId, String deviceId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            String normalizedDeviceId = requireText(deviceId, "deviceId");
            DeviceRecord device = repository.findDeviceById(normalizedDeviceId);
            if (device == null || !device.userId().equals(normalizedUserId)) {
                throw new NotFoundException("Device not found: " + normalizedDeviceId);
            }
            repository.saveDevice(device.withEnabled(false, Instant.now()));
            return null;
        });
    }

    private void seed() {
        Instant now = Instant.now();
        repository.savePreferences("user_current", defaultPreferences());
        DeviceRecord device = new DeviceRecord(
                "device_seed_current",
                "user_current",
                "android",
                "seed-token-current",
                "Pixel Camera",
                "id-ID",
                "0.1.0",
                true,
                now.minusSeconds(3_600),
                now.minusSeconds(300));
        repository.saveDevice(device);
        NotificationRecord friendRequest = new NotificationRecord(
                "notification_seed_friend",
                "user_current",
                "friend_request",
                "New friend request",
                "user_pending wants to connect after seeing your trail.",
                "/social/friend-requests",
                "info",
                List.of("in_app", "push"),
                List.of("in_app", "push"),
                Map.of("requestId", "friend_request_seed_pending"),
                false,
                false,
                now.minusSeconds(1_200),
                null,
                null);
        NotificationRecord safety = new NotificationRecord(
                "notification_seed_safety",
                "user_current",
                "safety_alert",
                "Location sharing reduced",
                "A blocked account tried to interact, so nearby visibility stayed hidden.",
                "/privacy",
                "warning",
                List.of("in_app", "push"),
                List.of("in_app", "push"),
                Map.of("ownerId", "user_blocked"),
                false,
                false,
                now.minusSeconds(600),
                null,
                null);
        repository.saveNotification(friendRequest);
        repository.saveNotification(safety);
    }

    private DeliveryDecision decideDelivery(
            String userId,
            String type,
            String severity,
            List<String> requestedChannels,
            NotificationPreferences userPreferences) {
        boolean muted = userPreferences.mutedTypes().contains(type) && !"critical".equals(severity);
        if (muted) {
            return new DeliveryDecision(List.of(), true);
        }
        List<String> channels = new ArrayList<>();
        for (String channel : requestedChannels) {
            if ("in_app".equals(channel) && userPreferences.inAppEnabled()) {
                channels.add(channel);
            } else if ("push".equals(channel) && userPreferences.pushEnabled() && hasEnabledDevice(userId)) {
                channels.add(channel);
            } else if ("email".equals(channel) && userPreferences.emailEnabled()) {
                channels.add(channel);
            }
        }
        if ("critical".equals(severity) && !channels.contains("in_app")) {
            channels.add("in_app");
        }
        return new DeliveryDecision(List.copyOf(channels), false);
    }

    private boolean hasEnabledDevice(String userId) {
        return repository.findAllDevices().stream()
                .anyMatch(device -> device.userId().equals(userId) && device.enabled());
    }

    private boolean isExpired(NotificationRecord notification) {
        return notification.expiresAt() != null && notification.expiresAt().isBefore(Instant.now());
    }

    private NotificationInboxResponse buildInbox(String userId, boolean onlyUnread, int max) {
        List<NotificationRecord> userNotifications = repository.findAllNotifications().stream()
                .filter(notification -> notification.userId().equals(userId))
                .filter(notification -> !isExpired(notification))
                .filter(notification -> !notification.muted() || "critical".equals(notification.severity()))
                .toList();
        List<NotificationResponse> items = userNotifications.stream()
                .filter(notification -> !onlyUnread || !notification.read())
                .sorted(Comparator.comparing(NotificationRecord::createdAt).reversed())
                .limit(max)
                .map(this::toResponse)
                .toList();
        int unreadCount = (int) userNotifications.stream()
                .filter(notification -> !notification.read())
                .count();
        return new NotificationInboxResponse(userId, unreadCount, items.size(), items);
    }

    private NotificationPreferences preferencesFor(String userId) {
        NotificationPreferences existing = repository.findPreferencesByUserId(userId);
        if (existing != null) {
            return existing;
        }
        NotificationPreferences defaults = defaultPreferences();
        repository.savePreferences(userId, defaults);
        return defaults;
    }

    private void saveDeliveryEvents(
            NotificationRecord notification,
            NotificationPreferences userPreferences,
            DeliveryDecision delivery,
            Instant createdAt) {
        Set<String> channels = new LinkedHashSet<>(notification.requestedChannels());
        channels.addAll(notification.deliveryChannels());
        channels.forEach(channel -> repository.saveDeliveryEvent(new NotificationDeliveryEvent(
                "notification_delivery_" + UUID.randomUUID(),
                notification.id(),
                notification.userId(),
                channel,
                deliveryStatus(notification, channel, delivery),
                deliveryReason(notification, channel, userPreferences, delivery),
                createdAt)));
    }

    private NotificationResponse createNotification(NotificationCreateRequest request) {
        validateCreate(request);
        String userId = requireText(request.userId(), "userId");
        String type = normalizeType(request.type());
        String severity = normalizeSeverity(request.severity());
        List<String> requestedChannels = normalizeChannels(request.channels());
        NotificationPreferences userPreferences = preferencesFor(userId);
        DeliveryDecision delivery = decideDelivery(userId, type, severity, requestedChannels, userPreferences);
        Instant now = Instant.now();
        NotificationRecord created = new NotificationRecord(
                "notification_" + UUID.randomUUID(),
                userId,
                type,
                requireText(request.title(), "title"),
                optionalTrim(request.body(), ""),
                optionalTrim(request.actionUrl(), ""),
                severity,
                requestedChannels,
                delivery.channels(),
                normalizeMetadata(request.metadata()),
                delivery.muted(),
                false,
                now,
                null,
                request.expiresAt());
        repository.saveNotification(created);
        saveDeliveryEvents(created, userPreferences, delivery, now);
        return toResponse(created);
    }

    private String deliveryStatus(NotificationRecord notification, String channel, DeliveryDecision delivery) {
        if (delivery.muted()) {
            return "suppressed";
        }
        return notification.deliveryChannels().contains(channel) ? "queued" : "skipped";
    }

    private String deliveryReason(
            NotificationRecord notification,
            String channel,
            NotificationPreferences userPreferences,
            DeliveryDecision delivery) {
        if (delivery.muted()) {
            return "muted_type";
        }
        if (notification.deliveryChannels().contains(channel)) {
            return notification.requestedChannels().contains(channel) ? "eligible" : "critical_in_app_fallback";
        }
        return switch (channel) {
            case "in_app" -> userPreferences.inAppEnabled() ? "not_selected" : "in_app_disabled";
            case "push" -> !userPreferences.pushEnabled()
                    ? "push_disabled"
                    : hasEnabledDevice(notification.userId()) ? "not_selected" : "no_enabled_device";
            case "email" -> userPreferences.emailEnabled() ? "not_selected" : "email_disabled";
            default -> "not_selected";
        };
    }

    private void validateCreate(NotificationCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.userId(), "userId");
        requireText(request.title(), "title");
        normalizeType(request.type());
        normalizeSeverity(request.severity());
        normalizeChannels(request.channels());
    }

    private void validateMessagingHandoff(MessagingNotificationHandoffRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.deliveryId(), "deliveryId");
        requireText(request.envelopeId(), "envelopeId");
        requireText(request.threadId(), "threadId");
        requireText(request.recipientUserId(), "recipientUserId");
        String target = requireText(request.deliveryTarget(), "deliveryTarget");
        if (!MESSAGING_DELIVERY_TARGET.equals(target)) {
            throw new BadRequestException("deliveryTarget must be notification");
        }
        String eventType = requireText(request.eventType(), "eventType");
        if (!EVENT_THREAD_CREATED.equals(eventType) && !EVENT_MESSAGE_SENT.equals(eventType)) {
            throw new BadRequestException("eventType is not notification eligible: " + eventType);
        }
    }

    private NotificationCreateRequest toMessagingNotificationRequest(MessagingNotificationHandoffRequest request) {
        String eventType = requireText(request.eventType(), "eventType");
        return new NotificationCreateRequest(
                requireText(request.recipientUserId(), "recipientUserId"),
                "messaging",
                titleForMessagingEvent(eventType),
                bodyForMessagingEvent(eventType, request.payload()),
                "/messaging/threads/" + requireText(request.threadId(), "threadId"),
                "info",
                List.of("in_app", "push"),
                messagingMetadata(request),
                null);
    }

    private NotificationRecord findBySourceDeliveryId(String deliveryId) {
        return repository.findAllNotifications().stream()
                .filter(notification -> SOURCE_MESSAGING_FANOUT.equals(notification.metadata().get("source")))
                .filter(notification -> deliveryId.equals(notification.metadata().get("sourceDeliveryId")))
                .findFirst()
                .orElse(null);
    }

    private String titleForMessagingEvent(String eventType) {
        return switch (eventType) {
            case EVENT_THREAD_CREATED -> "New chat";
            case EVENT_MESSAGE_SENT -> "New message";
            default -> "Messaging update";
        };
    }

    private String bodyForMessagingEvent(String eventType, Map<String, Object> payload) {
        String actor = payloadText(payload, "actorUserId", "Someone");
        return switch (eventType) {
            case EVENT_THREAD_CREATED -> actor + " added you to a chat.";
            case EVENT_MESSAGE_SENT -> actor + " sent a message.";
            default -> payloadText(payload, "detail", "You have a messaging update.");
        };
    }

    private Map<String, String> messagingMetadata(MessagingNotificationHandoffRequest request) {
        Map<String, String> metadata = new LinkedHashMap<>();
        metadata.put("source", SOURCE_MESSAGING_FANOUT);
        metadata.put("sourceDeliveryId", requireText(request.deliveryId(), "deliveryId"));
        metadata.put("envelopeId", requireText(request.envelopeId(), "envelopeId"));
        metadata.put("threadId", requireText(request.threadId(), "threadId"));
        metadata.put("eventType", requireText(request.eventType(), "eventType"));
        putPayloadText(metadata, request.payload(), "outboxId");
        putPayloadText(metadata, request.payload(), "activityId");
        putPayloadText(metadata, request.payload(), "actorUserId");
        putPayloadText(metadata, request.payload(), "targetId");
        String messageId = payloadText(request.payload(), "targetId", "");
        if (EVENT_MESSAGE_SENT.equals(request.eventType()) && !messageId.isEmpty()) {
            metadata.put("messageId", messageId);
        }
        return Map.copyOf(metadata);
    }

    private void putPayloadText(Map<String, String> metadata, Map<String, Object> payload, String key) {
        String value = payloadText(payload, key, "");
        if (!value.isEmpty()) {
            metadata.put(key, value);
        }
    }

    private String payloadText(Map<String, Object> payload, String key, String defaultValue) {
        if (payload == null) {
            return defaultValue;
        }
        Object value = payload.get(key);
        if (value == null) {
            return defaultValue;
        }
        String text = value.toString().trim();
        return text.isEmpty() ? defaultValue : text;
    }

    private NotificationResponse toResponse(NotificationRecord notification) {
        return new NotificationResponse(
                notification.id(),
                notification.userId(),
                notification.type(),
                notification.title(),
                notification.body(),
                notification.actionUrl(),
                notification.severity(),
                notification.requestedChannels(),
                notification.deliveryChannels(),
                notification.metadata(),
                notification.muted(),
                notification.read(),
                notification.createdAt(),
                notification.readAt(),
                notification.expiresAt());
    }

    private NotificationDeliveryEventResponse toResponse(NotificationDeliveryEvent event) {
        return new NotificationDeliveryEventResponse(
                event.eventId(),
                event.notificationId(),
                event.userId(),
                event.channel(),
                event.status(),
                event.reason(),
                event.createdAt());
    }

    private DeviceRegistrationResponse toResponse(DeviceRecord device) {
        return new DeviceRegistrationResponse(
                device.id(),
                device.userId(),
                device.platform(),
                device.pushToken(),
                device.deviceName(),
                device.locale(),
                device.appVersion(),
                device.enabled(),
                device.createdAt(),
                device.updatedAt());
    }

    private NotificationPreferences defaultPreferences() {
        return new NotificationPreferences(true, true, false, "22:00", "06:00", List.of());
    }

    private String normalizeType(String value) {
        return requireChoice(value, TYPES, "type", "type must be one of " + TYPES);
    }

    private String normalizeSeverity(String value) {
        return optionalChoice(value, "info", NOTIFICATION_SEVERITIES, "severity",
                "severity must be info, warning, or critical");
    }

    private String normalizePlatform(String value) {
        return requireChoice(value, PLATFORMS, "platform", "platform must be ios, android, web, or macos");
    }

    private List<String> normalizeChannels(List<String> channels) {
        List<String> source = channels == null || channels.isEmpty() ? List.of("in_app", "push") : channels;
        List<String> normalized = new ArrayList<>();
        for (String channel : source) {
            String value = requireChoice(channel, NOTIFICATION_CHANNELS, "channel",
                    "channel must be in_app, push, or email");
            if (!normalized.contains(value)) {
                normalized.add(value);
            }
        }
        return List.copyOf(normalized);
    }

    private List<String> normalizeMutedTypes(List<String> mutedTypes) {
        if (mutedTypes == null || mutedTypes.isEmpty()) {
            return List.of();
        }
        List<String> normalized = new ArrayList<>();
        for (String type : mutedTypes) {
            String value = normalizeType(type);
            if (!normalized.contains(value)) {
                normalized.add(value);
            }
        }
        return List.copyOf(normalized);
    }

    private Map<String, String> normalizeMetadata(Map<String, String> metadata) {
        if (metadata == null || metadata.isEmpty()) {
            return Map.of();
        }
        Map<String, String> normalized = new LinkedHashMap<>();
        metadata.forEach((key, value) -> {
            String normalizedKey = optionalTrim(key, null);
            String normalizedValue = optionalTrim(value, "");
            if (normalizedKey != null) {
                normalized.put(normalizedKey, normalizedValue);
            }
        });
        return Map.copyOf(normalized);
    }

    private record DeliveryDecision(List<String> channels, boolean muted) {
    }
}
