package tech.kayys.jezaku.messaging;

import java.util.Set;

final class MessagingSchema {
    static final String THREADS_TABLE = "messaging_threads";
    static final String MESSAGES_TABLE = "messaging_messages";
    static final String READ_RECEIPTS_TABLE = "messaging_read_receipts";
    static final String MUTES_TABLE = "messaging_mutes";
    static final String ACTIVITY_TABLE = "messaging_activity";
    static final String OUTBOX_TABLE = "messaging_outbox";
    static final String FANOUT_TABLE = "messaging_fanout_envelopes";
    static final String FANOUT_TARGET_DELIVERIES_TABLE = "messaging_fanout_target_deliveries";

    static final String STATUS_ACTIVE = "active";
    static final String STATUS_ARCHIVED = "archived";
    static final String STATUS_DELETED = "deleted";
    static final String OUTBOX_STATUS_PENDING = "pending";
    static final String OUTBOX_STATUS_DISPATCHED = "dispatched";
    static final String OUTBOX_STATUS_FAILED = "failed";
    static final String FANOUT_STATUS_QUEUED = "queued";
    static final String FANOUT_STATUS_DELIVERED = "delivered";
    static final String FANOUT_STATUS_FAILED = "failed";
    static final String FANOUT_TARGET_DELIVERY_STATUS_READY = "ready";
    static final String FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED = "acknowledged";

    static final String FANOUT_TARGET_REALTIME = "realtime";
    static final String FANOUT_TARGET_NOTIFICATION = "notification";

    static final String THREAD_TYPE_DIRECT = "direct";
    static final String THREAD_TYPE_GROUP = "group";
    static final String THREAD_TYPE_PLACE = "place";
    static final String THREAD_TYPE_EVENT = "event";
    static final String THREAD_TYPE_JOURNEY = "journey";
    static final String THREAD_TYPE_MEMORY = "memory";

    static final String ACTIVITY_THREAD_CREATED = "thread_created";
    static final String ACTIVITY_MESSAGE_SENT = "message_sent";
    static final String ACTIVITY_MESSAGE_DELETED = "message_deleted";
    static final String ACTIVITY_READ = "read";
    static final String ACTIVITY_MUTED = "muted";
    static final String ACTIVITY_UNMUTED = "unmuted";

    static final String EVENT_THREAD_CREATED = "messaging.thread.created";
    static final String EVENT_MESSAGE_SENT = "messaging.message.sent";
    static final String EVENT_MESSAGE_DELETED = "messaging.message.deleted";
    static final String EVENT_THREAD_READ = "messaging.thread.read";
    static final String EVENT_THREAD_MUTED = "messaging.thread.muted";
    static final String EVENT_THREAD_UNMUTED = "messaging.thread.unmuted";

    static final Set<String> REQUIRED_TABLES = Set.of(
            THREADS_TABLE,
            MESSAGES_TABLE,
            READ_RECEIPTS_TABLE,
            MUTES_TABLE,
            ACTIVITY_TABLE,
            OUTBOX_TABLE,
            FANOUT_TABLE,
            FANOUT_TARGET_DELIVERIES_TABLE);

    static final Set<String> REQUIRED_THREAD_COLUMNS = Set.of(
            "thread_id",
            "thread_type",
            "target_type",
            "target_id",
            "title",
            "participant_ids",
            "status",
            "created_at",
            "updated_at");

    static final Set<String> REQUIRED_MESSAGE_COLUMNS = Set.of(
            "message_id",
            "thread_id",
            "sender_id",
            "body",
            "media_ids",
            "position_latitude",
            "position_longitude",
            "position_altitude_meters",
            "status",
            "created_at",
            "updated_at");

    static final Set<String> REQUIRED_ACTIVITY_COLUMNS = Set.of(
            "activity_id",
            "thread_id",
            "actor_user_id",
            "activity_type",
            "target_id",
            "detail",
            "created_at");

    static final Set<String> REQUIRED_OUTBOX_COLUMNS = Set.of(
            "outbox_id",
            "aggregate_type",
            "aggregate_id",
            "event_type",
            "payload",
            "status",
            "attempts",
            "created_at",
            "next_attempt_at",
            "processed_at",
            "updated_at",
            "last_error");

    static final Set<String> REQUIRED_FANOUT_COLUMNS = Set.of(
            "envelope_id",
            "outbox_id",
            "thread_id",
            "recipient_user_id",
            "event_type",
            "delivery_targets",
            "payload",
            "status",
            "attempts",
            "created_at",
            "next_attempt_at",
            "delivered_at",
            "updated_at",
            "last_error");

    static final Set<String> REQUIRED_FANOUT_TARGET_DELIVERY_COLUMNS = Set.of(
            "delivery_id",
            "envelope_id",
            "thread_id",
            "recipient_user_id",
            "delivery_target",
            "event_type",
            "payload",
            "status",
            "created_at",
            "acknowledged_at",
            "updated_at");

    static final Set<String> THREAD_TYPES = Set.of(
            THREAD_TYPE_DIRECT,
            THREAD_TYPE_GROUP,
            THREAD_TYPE_PLACE,
            THREAD_TYPE_EVENT,
            THREAD_TYPE_JOURNEY,
            THREAD_TYPE_MEMORY);

    static final Set<String> THREAD_STATUS_VALUES = Set.of(STATUS_ACTIVE, STATUS_ARCHIVED);
    static final Set<String> MESSAGE_STATUS_VALUES = Set.of(STATUS_ACTIVE, STATUS_DELETED);
    static final Set<String> OUTBOX_STATUS_VALUES = Set.of(
            OUTBOX_STATUS_PENDING,
            OUTBOX_STATUS_DISPATCHED,
            OUTBOX_STATUS_FAILED);
    static final Set<String> FANOUT_STATUS_VALUES = Set.of(
            FANOUT_STATUS_QUEUED,
            FANOUT_STATUS_DELIVERED,
            FANOUT_STATUS_FAILED);
    static final Set<String> FANOUT_TARGETS = Set.of(FANOUT_TARGET_REALTIME, FANOUT_TARGET_NOTIFICATION);
    static final Set<String> FANOUT_TARGET_DELIVERY_STATUS_VALUES = Set.of(
            FANOUT_TARGET_DELIVERY_STATUS_READY,
            FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED);
    static final Set<String> ACTIVITY_TYPES = Set.of(
            ACTIVITY_THREAD_CREATED,
            ACTIVITY_MESSAGE_SENT,
            ACTIVITY_MESSAGE_DELETED,
            ACTIVITY_READ,
            ACTIVITY_MUTED,
            ACTIVITY_UNMUTED);
    static final Set<String> OUTBOX_EVENT_TYPES = Set.of(
            EVENT_THREAD_CREATED,
            EVENT_MESSAGE_SENT,
            EVENT_MESSAGE_DELETED,
            EVENT_THREAD_READ,
            EVENT_THREAD_MUTED,
            EVENT_THREAD_UNMUTED);

    private MessagingSchema() {
    }
}
