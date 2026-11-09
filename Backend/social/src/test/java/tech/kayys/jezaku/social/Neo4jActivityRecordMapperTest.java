package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.Values;
import org.neo4j.driver.internal.InternalRecord;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Verifies Neo4j activity row mapping and write parameter generation.
 */
class Neo4jActivityRecordMapperTest {
    private static final Instant NOW = Instant.parse("2026-06-09T04:00:00Z");

    private final Neo4jActivityRecordMapper mapper = new Neo4jActivityRecordMapper();

    @Test
    void mapsActivityRowsAndParameters() {
        SocialActivityRecord activity = mapper.activity(record(fields(
                "activityId", "activity_a",
                "eventType", "comment_mentioned",
                "actorId", "author_a",
                "recipientId", "viewer_a",
                "contentId", "content_a",
                "commentId", "comment_a",
                "reactionType", "",
                "message", "hello",
                "createdAt", NOW.toString(),
                "read", true)));

        Map<String, Object> parameters = mapper.activityParameters(activity);

        assertEquals("comment_mentioned", activity.eventType());
        assertEquals("viewer_a", activity.recipientId());
        assertTrue(activity.read());
        assertEquals("activity_a", parameters.get("activityId"));
        assertEquals("author_a", parameters.get("actorId"));
        assertEquals("2026-06-09T04:00:00Z", parameters.get("createdAt"));
        assertEquals(true, parameters.get("read"));
    }

    private Map<String, Object> fields(Object... pairs) {
        Map<String, Object> fields = new LinkedHashMap<>();
        for (int index = 0; index < pairs.length; index += 2) {
            fields.put((String) pairs[index], pairs[index + 1]);
        }
        return fields;
    }

    private Record record(Map<String, Object> fields) {
        List<String> keys = new ArrayList<>(fields.keySet());
        List<Value> values = fields.values().stream()
                .map(Values::value)
                .toList();
        return new InternalRecord(keys, values);
    }
}
