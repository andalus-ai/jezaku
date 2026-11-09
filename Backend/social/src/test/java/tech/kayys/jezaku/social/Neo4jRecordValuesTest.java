package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.Values;
import org.neo4j.driver.internal.InternalRecord;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class Neo4jRecordValuesTest {
    private static final Instant NOW = Instant.parse("2026-06-09T04:00:00Z");

    @Test
    void readsDriverTemporalShapesAsInstants() {
        assertEquals(
                NOW,
                Neo4jRecordValues.instant(record("createdAt", Values.value(NOW.toString())), "createdAt"));
        assertEquals(
                NOW,
                Neo4jRecordValues.instant(
                        record("createdAt", Values.value(OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC))),
                        "createdAt"));
        assertEquals(
                NOW,
                Neo4jRecordValues.instant(
                        record("createdAt", Values.value(ZonedDateTime.ofInstant(NOW, ZoneOffset.UTC))),
                        "createdAt"));
        assertEquals(
                NOW,
                Neo4jRecordValues.instant(
                        record("createdAt", Values.value(LocalDateTime.ofInstant(NOW, ZoneOffset.UTC))),
                        "createdAt"));
    }

    @Test
    void readsNullableInstants() {
        assertNull(Neo4jRecordValues.nullableInstant(record("reviewedAt", Values.NULL), "reviewedAt"));
        assertEquals(
                NOW,
                Neo4jRecordValues.nullableInstant(
                        record("reviewedAt", Values.value(NOW.toString())),
                        "reviewedAt"));
    }

    @Test
    void readsStringListsAndFormatsInstants() {
        Record record = record("tags", Values.value(List.of("city", "food")));

        assertEquals(List.of("city", "food"), Neo4jRecordValues.stringList(record, "tags"));
        assertEquals("2026-06-09T04:00:00Z", Neo4jRecordValues.iso(NOW));
    }

    private Record record(String field, Value value) {
        return new InternalRecord(List.of(field), List.of(value));
    }
}
