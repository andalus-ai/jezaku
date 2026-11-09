package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;

import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jRecordValues.instant;
import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;

/**
 * Maps Neo4j activity rows into notification records and persistence parameters.
 */
final class Neo4jActivityRecordMapper {
    SocialActivityRecord activity(Record record) {
        return new SocialActivityRecord(
                record.get("activityId").asString(),
                record.get("eventType").asString(),
                record.get("actorId").asString(),
                record.get("recipientId").asString(),
                record.get("contentId").asString(),
                record.get("commentId").asString(),
                record.get("reactionType").asString(),
                record.get("message").asString(),
                instant(record, "createdAt"),
                record.get("read").asBoolean(false));
    }

    Map<String, Object> activityParameters(SocialActivityRecord activity) {
        return Map.of(
                "activityId", activity.activityId(),
                "eventType", activity.eventType(),
                "actorId", activity.actorId(),
                "recipientId", activity.recipientId(),
                "contentId", activity.contentId(),
                "commentId", activity.commentId(),
                "reactionType", activity.reactionType(),
                "message", activity.message(),
                "createdAt", iso(activity.createdAt()),
                "read", activity.read());
    }
}
