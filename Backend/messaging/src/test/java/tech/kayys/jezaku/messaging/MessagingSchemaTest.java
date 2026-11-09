package tech.kayys.jezaku.messaging;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertTrue;

class MessagingSchemaTest {
    private static final List<String> MIGRATION_RESOURCES = List.of(
            "db/migration/V1__messaging_core.sql",
            "db/migration/V2__messaging_outbox.sql",
            "db/migration/V3__messaging_outbox_dispatch.sql",
            "db/migration/V4__messaging_fanout.sql",
            "db/migration/V5__messaging_fanout_delivery.sql",
            "db/migration/V6__messaging_fanout_target_deliveries.sql",
            "db/migration/V7__messaging_realtime_target_ack.sql");

    @Test
    void migrationContainsRequiredTablesAndColumns() throws IOException {
        String sql = migrationSql();

        for (String table : MessagingSchema.REQUIRED_TABLES) {
            assertTrue(sql.contains("create table " + table), "missing table " + table);
        }
        for (String column : MessagingSchema.REQUIRED_THREAD_COLUMNS) {
            assertTrue(sql.contains(column), "missing thread column " + column);
        }
        for (String column : MessagingSchema.REQUIRED_MESSAGE_COLUMNS) {
            assertTrue(sql.contains(column), "missing message column " + column);
        }
        for (String column : MessagingSchema.REQUIRED_ACTIVITY_COLUMNS) {
            assertTrue(sql.contains(column), "missing activity column " + column);
        }
        for (String column : MessagingSchema.REQUIRED_OUTBOX_COLUMNS) {
            assertTrue(sql.contains(column), "missing outbox column " + column);
        }
        for (String column : MessagingSchema.REQUIRED_FANOUT_COLUMNS) {
            assertTrue(sql.contains(column), "missing fanout column " + column);
        }
        for (String column : MessagingSchema.REQUIRED_FANOUT_TARGET_DELIVERY_COLUMNS) {
            assertTrue(sql.contains(column), "missing fanout target delivery column " + column);
        }
    }

    @Test
    void migrationLocksLookupValuesAndIndexes() throws IOException {
        String sql = migrationSql();

        for (String value : MessagingSchema.THREAD_TYPES) {
            assertTrue(sql.contains("'" + value + "'"), "missing thread type " + value);
        }
        for (String value : MessagingSchema.THREAD_STATUS_VALUES) {
            assertTrue(sql.contains("'" + value + "'"), "missing thread status " + value);
        }
        for (String value : MessagingSchema.MESSAGE_STATUS_VALUES) {
            assertTrue(sql.contains("'" + value + "'"), "missing message status " + value);
        }
        for (String value : MessagingSchema.ACTIVITY_TYPES) {
            assertTrue(sql.contains("'" + value + "'"), "missing activity type " + value);
        }
        for (String value : MessagingSchema.OUTBOX_EVENT_TYPES) {
            assertTrue(sql.contains("'" + value + "'"), "missing outbox event type " + value);
        }
        for (String value : MessagingSchema.OUTBOX_STATUS_VALUES) {
            assertTrue(sql.contains("'" + value + "'"), "missing outbox status " + value);
        }
        for (String value : MessagingSchema.FANOUT_STATUS_VALUES) {
            assertTrue(sql.contains("'" + value + "'"), "missing fanout status " + value);
        }
        for (String value : MessagingSchema.FANOUT_TARGETS) {
            assertTrue(sql.contains(value), "missing fanout target " + value);
        }
        for (String value : MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_VALUES) {
            assertTrue(sql.contains("'" + value + "'"), "missing fanout target delivery status " + value);
        }

        assertTrue(sql.contains("idx_messaging_threads_status_updated_at"));
        assertTrue(sql.contains("idx_messaging_threads_target"));
        assertTrue(sql.contains("idx_messaging_messages_thread_created"));
        assertTrue(sql.contains("idx_messaging_messages_sender"));
        assertTrue(sql.contains("idx_messaging_activity_thread_created"));
        assertTrue(sql.contains("idx_messaging_outbox_pending"));
        assertTrue(sql.contains("idx_messaging_outbox_aggregate"));
        assertTrue(sql.contains("idx_messaging_outbox_retry"));
        assertTrue(sql.contains("idx_messaging_fanout_recipient_status_created"));
        assertTrue(sql.contains("idx_messaging_fanout_thread_created"));
        assertTrue(sql.contains("idx_messaging_fanout_retry"));
        assertTrue(sql.contains("idx_messaging_target_delivery_recipient_target_created"));
        assertTrue(sql.contains("idx_messaging_target_delivery_envelope"));
        assertTrue(sql.contains("idx_messaging_target_delivery_realtime_ready"));
        assertTrue(sql.contains("references messaging_threads(thread_id) on delete cascade"));
        assertTrue(sql.contains("references messaging_outbox(outbox_id) on delete cascade"));
        assertTrue(sql.contains("references messaging_fanout_envelopes(envelope_id) on delete cascade"));
        assertTrue(sql.contains("jsonb_typeof(participant_ids) = 'array'"));
        assertTrue(sql.contains("jsonb_typeof(media_ids) = 'array'"));
        assertTrue(sql.contains("jsonb_typeof(payload) = 'object'"));
        assertTrue(sql.contains("jsonb_typeof(delivery_targets) = 'array'"));
        assertTrue(sql.contains("unique (outbox_id, recipient_user_id)"));
        assertTrue(sql.contains("unique (envelope_id, delivery_target)"));
        assertTrue(sql.contains("position_latitude is not null"));
        assertTrue(sql.contains("position_longitude is not null"));
        assertTrue(sql.contains("position_latitude between -90 and 90"));
        assertTrue(sql.contains("position_longitude between -180 and 180"));
        assertTrue(sql.contains("where status = 'pending'"));
        assertTrue(sql.contains("where status in ('pending', 'failed')"));
        assertTrue(sql.contains("where status in ('queued', 'failed')"));
        assertTrue(sql.contains("attempts >= 0"));
        assertTrue(sql.contains("next_attempt_at >= created_at"));
        assertTrue(sql.contains("updated_at >= created_at"));
        assertTrue(sql.contains("acknowledged_at is null or acknowledged_at >= created_at"));
        assertTrue(sql.contains("delivery_target = 'realtime' and status = 'ready'"));
    }

    private String migrationSql() throws IOException {
        StringBuilder sql = new StringBuilder();
        for (String resource : MIGRATION_RESOURCES) {
            try (var stream = getClass().getClassLoader().getResourceAsStream(resource)) {
                assertTrue(stream != null, "missing migration resource " + resource);
                sql.append(new String(stream.readAllBytes(), StandardCharsets.UTF_8));
                sql.append('\n');
            }
        }
        return sql.toString();
    }
}
