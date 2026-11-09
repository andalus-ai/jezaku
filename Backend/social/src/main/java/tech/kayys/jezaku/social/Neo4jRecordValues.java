package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;
import org.neo4j.driver.Value;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.List;

final class Neo4jRecordValues {
    private Neo4jRecordValues() {
    }

    static Instant instant(Record record, String field) {
        return instant(record.get(field));
    }

    static Instant nullableInstant(Record record, String field) {
        Value value = record.get(field);
        if (value.isNull()) {
            return null;
        }
        return instant(value);
    }

    static List<String> stringList(Record record, String field) {
        return record.get(field).asList(Value::asString);
    }

    static String iso(Instant instant) {
        return instant.toString();
    }

    private static Instant instant(Value value) {
        Object object = value.asObject();
        if (object instanceof Instant instant) {
            return instant;
        }
        if (object instanceof OffsetDateTime offsetDateTime) {
            return offsetDateTime.toInstant();
        }
        if (object instanceof ZonedDateTime zonedDateTime) {
            return zonedDateTime.toInstant();
        }
        if (object instanceof LocalDateTime localDateTime) {
            return localDateTime.toInstant(ZoneOffset.UTC);
        }
        return Instant.parse(value.asString());
    }
}
