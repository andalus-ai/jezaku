package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for social activity and notification graph records.
 */
final class Neo4jActivityCypher {
    static final String READ_ACTIVITY = """
            MATCH (activity:Activity {activityId: $activityId})
            RETURN activity.activityId AS activityId,
                   activity.eventType AS eventType,
                   activity.actorId AS actorId,
                   activity.recipientId AS recipientId,
                   coalesce(activity.contentId, '') AS contentId,
                   coalesce(activity.commentId, '') AS commentId,
                   coalesce(activity.reactionType, '') AS reactionType,
                   coalesce(activity.message, '') AS message,
                   activity.createdAt AS createdAt,
                   activity.read AS read
            """;
    static final String READ_ACTIVITIES = """
            MATCH (activity:Activity)
            RETURN activity.activityId AS activityId,
                   activity.eventType AS eventType,
                   activity.actorId AS actorId,
                   activity.recipientId AS recipientId,
                   coalesce(activity.contentId, '') AS contentId,
                   coalesce(activity.commentId, '') AS commentId,
                   coalesce(activity.reactionType, '') AS reactionType,
                   coalesce(activity.message, '') AS message,
                   activity.createdAt AS createdAt,
                   activity.read AS read
            ORDER BY activity.createdAt DESC, activity.activityId
            """;
    static final String SAVE_ACTIVITY = """
            MERGE (activity:Activity {activityId: $activityId})
            SET activity.eventType = $eventType,
                activity.actorId = $actorId,
                activity.recipientId = $recipientId,
                activity.contentId = $contentId,
                activity.commentId = $commentId,
                activity.reactionType = $reactionType,
                activity.message = $message,
                activity.createdAt = $createdAt,
                activity.read = $read
            WITH activity
            MERGE (actor:User {userId: $actorId})
            MERGE (recipient:User {userId: $recipientId})
            MERGE (actor)-[acted:PERFORMED]->(activity)
            SET acted.createdAt = $createdAt
            MERGE (activity)-[delivered:DELIVERED_TO]->(recipient)
            SET delivered.createdAt = $createdAt
            """;
    static final String DELETE_ACTIVITIES_FOR_CONTENT = """
            MATCH (activity:Activity {contentId: $contentId})
            DETACH DELETE activity
            """;

    private Neo4jActivityCypher() {
    }
}
