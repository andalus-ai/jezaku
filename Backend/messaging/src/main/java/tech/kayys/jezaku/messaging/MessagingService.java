package tech.kayys.jezaku.messaging;

import io.smallrye.mutiny.Uni;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.messaging.MessagingDtos.GeoPoint;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageCreateRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.MessageResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadActivityHistoryResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadActivityResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.MuteRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.MuteResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeAckRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeAckResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeEventListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.RealtimeEventResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ReadReceiptRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.ReadReceiptResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadCreateRequest;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadListResponse;
import tech.kayys.jezaku.messaging.MessagingDtos.ThreadResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import static tech.kayys.jezaku.taxonomy.JezakuTargetTypes.MESSAGING_TARGET_TYPES;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.clampInt;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

@ApplicationScoped
public class MessagingService {
    private static final int MAX_MESSAGE_LENGTH = 1_000;

    @Inject
    MessagingRepository repository;

    @PostConstruct
    void initialize() {
        seed();
    }

    public Uni<ThreadResponse> createThread(ThreadCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateThreadCreate(request);
            Instant now = Instant.now();
            String creatorId = requireText(request.creatorId(), "creatorId");
            String threadType = normalizeThreadType(request.threadType());
            String targetType = normalizeTargetType(request.targetType(), threadType);
            String targetId = targetType.isEmpty() ? "" : requireText(request.targetId(), "targetId");
            List<String> participants = normalizeParticipants(request.participantIds(), creatorId);
            ThreadRecord record = new ThreadRecord(
                    "thread_" + UUID.randomUUID(),
                    threadType,
                    targetType,
                    targetId,
                    optionalTrim(request.title(), defaultTitle(threadType, targetType, targetId)),
                    participants,
                    MessagingSchema.STATUS_ACTIVE,
                    now,
                    now);
            repository.saveThread(record);
            recordActivity(record.threadId(), creatorId, MessagingSchema.ACTIVITY_THREAD_CREATED,
                    record.threadId(), record.title(), now);
            return toThreadResponse(record, creatorId);
        });
    }

    public Uni<ThreadListResponse> userThreads(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<ThreadResponse> result = repository.findAllThreads().stream()
                    .filter(thread -> thread.participantIds().contains(normalizedUserId))
                    .filter(thread -> MessagingSchema.STATUS_ACTIVE.equals(thread.status()))
                    .sorted(Comparator.comparing(ThreadRecord::updatedAt).reversed())
                    .map(thread -> toThreadResponse(thread, normalizedUserId))
                    .toList();
            return new ThreadListResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<ThreadResponse> thread(String threadId, String viewerId) {
        return Uni.createFrom().item(() -> {
            ThreadRecord thread = requireThread(threadId);
            String viewer = optionalTrim(viewerId, "");
            if (!viewer.isEmpty()) {
                requireParticipant(thread, viewer);
            }
            return toThreadResponse(thread, viewer);
        });
    }

    public Uni<ThreadResponse> contextThread(String targetType, String targetId, String viewerId) {
        return Uni.createFrom().item(() -> {
            String normalizedTargetType = normalizeTargetType(targetType, targetType);
            String normalizedTargetId = requireText(targetId, "targetId");
            ThreadRecord thread = repository.findAllThreads().stream()
                    .filter(item -> item.targetType().equals(normalizedTargetType))
                    .filter(item -> item.targetId().equals(normalizedTargetId))
                    .filter(item -> MessagingSchema.STATUS_ACTIVE.equals(item.status()))
                    .findFirst()
                    .orElseThrow(() -> new NotFoundException("Context thread not found"));
            String viewer = optionalTrim(viewerId, "");
            if (!viewer.isEmpty()) {
                requireParticipant(thread, viewer);
            }
            return toThreadResponse(thread, viewer);
        });
    }

    public Uni<MessageResponse> sendMessage(String threadId, MessageCreateRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            ThreadRecord thread = requireThread(threadId);
            String senderId = requireText(request.senderId(), "senderId");
            requireParticipant(thread, senderId);
            String body = normalizeBody(request.body());
            if (request.position() != null) {
                validateLatLng(request.position().latitude(), request.position().longitude());
            }
            Instant now = Instant.now();
            MessageRecord message = new MessageRecord(
                    "message_" + UUID.randomUUID(),
                    thread.threadId(),
                    senderId,
                    body,
                    normalizeMediaIds(request.mediaIds()),
                    request.position(),
                    MessagingSchema.STATUS_ACTIVE,
                    now,
                    now);
            repository.saveMessage(message);
            repository.saveThread(thread.withUpdatedAt(now));
            recordActivity(thread.threadId(), senderId, MessagingSchema.ACTIVITY_MESSAGE_SENT,
                    message.messageId(), "Message sent", now);
            return toMessageResponse(message);
        });
    }

    public Uni<MessageListResponse> messages(String threadId) {
        return Uni.createFrom().item(() -> {
            ThreadRecord thread = requireThread(threadId);
            List<MessageResponse> result = repository.findAllMessages().stream()
                    .filter(message -> message.threadId().equals(thread.threadId()))
                    .filter(message -> MessagingSchema.STATUS_ACTIVE.equals(message.status()))
                    .sorted(Comparator.comparing(MessageRecord::createdAt))
                    .map(this::toMessageResponse)
                    .toList();
            return new MessageListResponse(thread.threadId(), result.size(), result);
        });
    }

    public Uni<Void> deleteMessage(String threadId, String messageId, String userId) {
        return Uni.createFrom().item(() -> {
            ThreadRecord thread = requireThread(threadId);
            String normalizedUserId = requireText(userId, "userId");
            requireParticipant(thread, normalizedUserId);
            MessageRecord message = requireMessage(messageId);
            if (!message.threadId().equals(thread.threadId())) {
                throw new NotFoundException("Message not found in thread");
            }
            if (!message.senderId().equals(normalizedUserId)) {
                throw new ForbiddenException("Message sender mismatch");
            }
            Instant now = Instant.now();
            repository.saveMessage(message.withStatus(MessagingSchema.STATUS_DELETED, now));
            recordActivity(thread.threadId(), normalizedUserId, MessagingSchema.ACTIVITY_MESSAGE_DELETED,
                    message.messageId(), "Message deleted", now);
            return null;
        });
    }

    public Uni<ReadReceiptResponse> markRead(String threadId, ReadReceiptRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            ThreadRecord thread = requireThread(threadId);
            String userId = requireText(request.userId(), "userId");
            requireParticipant(thread, userId);
            Instant now = Instant.now();
            repository.saveReadReceipt(thread.threadId(), userId, now);
            recordActivity(thread.threadId(), userId, MessagingSchema.ACTIVITY_READ, userId, "Thread marked read", now);
            return new ReadReceiptResponse(thread.threadId(), userId, now, unreadCount(thread, userId));
        });
    }

    public Uni<ThreadActivityHistoryResponse> activity(String threadId, String viewerId) {
        return Uni.createFrom().item(() -> {
            ThreadRecord thread = requireThread(threadId);
            String viewer = requireText(viewerId, "viewerId");
            requireParticipant(thread, viewer);
            List<ThreadActivityResponse> activity = repository.findActivityByThreadId(thread.threadId()).stream()
                    .sorted(Comparator.comparing(MessagingActivityEvent::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new ThreadActivityHistoryResponse(thread.threadId(), activity.size(), activity);
        });
    }

    public Uni<MuteResponse> mute(String threadId, MuteRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            ThreadRecord thread = requireThread(threadId);
            String userId = requireText(request.userId(), "userId");
            requireParticipant(thread, userId);
            Instant now = Instant.now();
            repository.saveMute(thread.threadId(), userId, request.muted());
            recordActivity(thread.threadId(), userId,
                    request.muted() ? MessagingSchema.ACTIVITY_MUTED : MessagingSchema.ACTIVITY_UNMUTED,
                    userId,
                    request.muted() ? "Thread muted" : "Thread unmuted", now);
            return new MuteResponse(thread.threadId(), userId, request.muted(), now);
        });
    }

    public Uni<RealtimeEventListResponse> realtimeEvents(String userId, Integer limit) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            int max = clampInt(limit, 50, 1, 100);
            List<RealtimeEventResponse> events = repository.findReadyRealtimeTargetDeliveries(normalizedUserId, max)
                    .stream()
                    .map(this::toRealtimeEventResponse)
                    .toList();
            return new RealtimeEventListResponse(normalizedUserId, events.size(), events);
        });
    }

    public Uni<RealtimeAckResponse> acknowledgeRealtimeEvents(String userId, RealtimeAckRequest request) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<String> deliveryIds = request == null ? List.of() : normalizeUniqueStrings(request.deliveryIds());
            if (deliveryIds.isEmpty()) {
                throw new BadRequestException("deliveryIds must include at least one id");
            }
            Instant now = Instant.now();
            int acknowledged = 0;
            for (MessagingFanoutTargetDelivery delivery : repository.findFanoutTargetDeliveriesByRecipientAndTarget(
                    normalizedUserId,
                    MessagingSchema.FANOUT_TARGET_REALTIME)) {
                if (deliveryIds.contains(delivery.deliveryId())) {
                    if (MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_READY.equals(delivery.status())) {
                        repository.saveFanoutTargetDelivery(delivery.markAcknowledged(now));
                        acknowledged++;
                    }
                }
            }
            return new RealtimeAckResponse(normalizedUserId, acknowledged, now);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        ThreadRecord direct = new ThreadRecord(
                "thread_seed_direct_current_rooftop",
                "direct",
                "",
                "",
                "Alya and Rafi",
                List.of("user_current", "user_rooftop"),
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(1_000),
                now.minusSeconds(600));
        ThreadRecord event = new ThreadRecord(
                "thread_seed_event_walk",
                "event",
                "event",
                "event_seed_campus_walk",
                "Campus Memory Walk Chat",
                List.of("user_current", "user_rooftop"),
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(900),
                now.minusSeconds(500));
        ThreadRecord journey = new ThreadRecord(
                "thread_seed_journey_anchor_loop",
                "journey",
                "journey",
                "journey_seed_anchor_loop",
                "Anchor Loop Party",
                List.of("user_current", "user_rooftop"),
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(800),
                now.minusSeconds(450));
        repository.saveThread(direct);
        repository.saveThread(event);
        repository.saveThread(journey);
        addMessage(new MessageRecord(
                "message_seed_direct_hello",
                direct.threadId(),
                "user_current",
                "Meet near the courtyard marker?",
                List.of(),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(650),
                now.minusSeconds(650)));
        addMessage(new MessageRecord(
                "message_seed_event_route",
                event.threadId(),
                "user_rooftop",
                "The rooftop checkpoint is clear.",
                List.of("media_seed_rooftop"),
                new GeoPoint(-6.890580, 107.610970, 746.4),
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(520),
                now.minusSeconds(520)));
        addMessage(new MessageRecord(
                "message_seed_journey_tip",
                journey.threadId(),
                "user_current",
                "Finish the courtyard checkpoint before the rooftop clue.",
                List.of(),
                null,
                MessagingSchema.STATUS_ACTIVE,
                now.minusSeconds(470),
                now.minusSeconds(470)));
    }

    private void validateThreadCreate(ThreadCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String creatorId = requireText(request.creatorId(), "creatorId");
        String threadType = normalizeThreadType(request.threadType());
        normalizeTargetType(request.targetType(), threadType);
        normalizeParticipants(request.participantIds(), creatorId);
    }

    private ThreadRecord requireThread(String threadId) {
        String normalizedThreadId = requireText(threadId, "threadId");
        ThreadRecord thread = repository.findThreadById(normalizedThreadId);
        if (thread == null || !MessagingSchema.STATUS_ACTIVE.equals(thread.status())) {
            throw new NotFoundException("Thread not found: " + normalizedThreadId);
        }
        return thread;
    }

    private MessageRecord requireMessage(String messageId) {
        String normalizedMessageId = requireText(messageId, "messageId");
        MessageRecord message = repository.findMessageById(normalizedMessageId);
        if (message == null || MessagingSchema.STATUS_DELETED.equals(message.status())) {
            throw new NotFoundException("Message not found: " + normalizedMessageId);
        }
        return message;
    }

    private void requireParticipant(ThreadRecord thread, String userId) {
        if (!thread.participantIds().contains(userId)) {
            throw new ForbiddenException("User is not a thread participant");
        }
    }

    private ThreadResponse toThreadResponse(ThreadRecord thread, String viewerId) {
        String viewer = optionalTrim(viewerId, "");
        return new ThreadResponse(
                thread.threadId(),
                thread.threadType(),
                thread.targetType(),
                thread.targetId(),
                thread.title(),
                thread.participantIds(),
                thread.status(),
                lastMessagePreview(thread.threadId()),
                viewer.isEmpty() ? 0 : unreadCount(thread, viewer),
                !viewer.isEmpty() && repository.isMuted(thread.threadId(), viewer),
                thread.createdAt(),
                thread.updatedAt());
    }

    private MessageResponse toMessageResponse(MessageRecord message) {
        return new MessageResponse(
                message.messageId(),
                message.threadId(),
                message.senderId(),
                message.body(),
                message.mediaIds(),
                message.position(),
                message.status(),
                message.createdAt(),
                message.updatedAt());
    }

    private ThreadActivityResponse toResponse(MessagingActivityEvent activity) {
        return new ThreadActivityResponse(
                activity.activityId(),
                activity.threadId(),
                activity.actorUserId(),
                activity.activityType(),
                activity.targetId(),
                activity.detail(),
                activity.createdAt());
    }

    private RealtimeEventResponse toRealtimeEventResponse(MessagingFanoutTargetDelivery delivery) {
        return new RealtimeEventResponse(
                delivery.deliveryId(),
                delivery.envelopeId(),
                delivery.threadId(),
                delivery.recipientUserId(),
                delivery.eventType(),
                delivery.payload(),
                delivery.createdAt());
    }

    private String lastMessagePreview(String threadId) {
        return repository.findAllMessages().stream()
                .filter(message -> message.threadId().equals(threadId))
                .filter(message -> MessagingSchema.STATUS_ACTIVE.equals(message.status()))
                .max(Comparator.comparing(MessageRecord::createdAt))
                .map(MessageRecord::body)
                .orElse("");
    }

    private int unreadCount(ThreadRecord thread, String userId) {
        Instant lastReadAt = repository.findReadReceiptAt(thread.threadId(), userId);
        if (lastReadAt == null) {
            lastReadAt = Instant.EPOCH;
        }
        Instant readAt = lastReadAt;
        return (int) repository.findAllMessages().stream()
                .filter(message -> message.threadId().equals(thread.threadId()))
                .filter(message -> MessagingSchema.STATUS_ACTIVE.equals(message.status()))
                .filter(message -> !message.senderId().equals(userId))
                .filter(message -> message.createdAt().isAfter(readAt))
                .count();
    }

    private void addMessage(MessageRecord message) {
        repository.saveMessage(message);
    }

    private void recordActivity(
            String threadId,
            String actorUserId,
            String activityType,
            String targetId,
            String detail,
            Instant createdAt) {
        if (!MessagingSchema.ACTIVITY_TYPES.contains(activityType)) {
            throw new IllegalArgumentException("Unsupported messaging activity type: " + activityType);
        }
        MessagingActivityEvent activity = new MessagingActivityEvent(
                "messaging_activity_" + UUID.randomUUID(),
                threadId,
                actorUserId,
                activityType,
                targetId,
                detail,
                createdAt);
        repository.saveActivity(activity);
        repository.saveOutboxEvent(toOutboxEvent(activity));
    }

    private MessagingOutboxEvent toOutboxEvent(MessagingActivityEvent activity) {
        return new MessagingOutboxEvent(
                "messaging_outbox_" + UUID.randomUUID(),
                "messaging_thread",
                activity.threadId(),
                eventTypeForActivity(activity.activityType()),
                Map.of(
                        "activityId", activity.activityId(),
                        "threadId", activity.threadId(),
                        "actorUserId", activity.actorUserId(),
                        "activityType", activity.activityType(),
                        "targetId", activity.targetId(),
                        "detail", activity.detail(),
                        "createdAt", activity.createdAt().toString()),
                MessagingSchema.OUTBOX_STATUS_PENDING,
                0,
                activity.createdAt(),
                activity.createdAt(),
                null,
                activity.createdAt(),
                "");
    }

    private String eventTypeForActivity(String activityType) {
        return switch (activityType) {
            case MessagingSchema.ACTIVITY_THREAD_CREATED -> MessagingSchema.EVENT_THREAD_CREATED;
            case MessagingSchema.ACTIVITY_MESSAGE_SENT -> MessagingSchema.EVENT_MESSAGE_SENT;
            case MessagingSchema.ACTIVITY_MESSAGE_DELETED -> MessagingSchema.EVENT_MESSAGE_DELETED;
            case MessagingSchema.ACTIVITY_READ -> MessagingSchema.EVENT_THREAD_READ;
            case MessagingSchema.ACTIVITY_MUTED -> MessagingSchema.EVENT_THREAD_MUTED;
            case MessagingSchema.ACTIVITY_UNMUTED -> MessagingSchema.EVENT_THREAD_UNMUTED;
            default -> throw new IllegalArgumentException("Unsupported messaging activity type: " + activityType);
        };
    }

    private String normalizeThreadType(String value) {
        return requireChoice(value, MessagingSchema.THREAD_TYPES, "threadType");
    }

    private String normalizeTargetType(String value, String threadType) {
        if (MessagingSchema.THREAD_TYPE_DIRECT.equals(threadType)
                || MessagingSchema.THREAD_TYPE_GROUP.equals(threadType)) {
            return optionalTrim(value, "");
        }
        return requireChoice(value, MESSAGING_TARGET_TYPES, "targetType");
    }

    private List<String> normalizeParticipants(List<String> participantIds, String creatorId) {
        List<String> result = new ArrayList<>();
        result.add(requireText(creatorId, "creatorId"));
        if (participantIds != null) {
            for (String participantId : participantIds) {
                String value = optionalTrim(participantId, null);
                if (value != null && !result.contains(value)) {
                    result.add(value);
                }
            }
        }
        result.sort(String::compareTo);
        if (result.size() < 2) {
            throw new BadRequestException("participantIds must include at least one participant besides creatorId");
        }
        return List.copyOf(result);
    }

    private String normalizeBody(String value) {
        return requireTextMaxLength(value, "body", MAX_MESSAGE_LENGTH);
    }

    private List<String> normalizeMediaIds(List<String> mediaIds) {
        return normalizeUniqueStrings(mediaIds);
    }

    private String defaultTitle(String threadType, String targetType, String targetId) {
        if (targetType == null || targetType.isEmpty()) {
            return threadType.substring(0, 1).toUpperCase(Locale.ROOT) + threadType.substring(1) + " Thread";
        }
        return targetType + ":" + targetId;
    }
}
