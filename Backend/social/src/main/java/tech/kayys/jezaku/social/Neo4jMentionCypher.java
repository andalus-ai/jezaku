package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for content and comment mention graph records.
 */
final class Neo4jMentionCypher {
    static final String READ_MENTIONS = """
            MATCH (content:Content {contentId: $contentId})-[mention:MENTIONS]->(mentioned:User)
            RETURN mention.mentionId AS mentionId,
                   content.contentId AS contentId,
                   coalesce(mention.commentId, '') AS commentId,
                   mention.actorId AS actorId,
                   mentioned.userId AS mentionedUserId,
                   mention.sourceType AS sourceType,
                   mention.createdAt AS createdAt
            ORDER BY mention.createdAt DESC, mention.mentionId
            """;
    static final String READ_MENTIONS_FOR_USER = """
            MATCH (content:Content)-[mention:MENTIONS]->(mentioned:User {userId: $userId})
            RETURN mention.mentionId AS mentionId,
                   content.contentId AS contentId,
                   coalesce(mention.commentId, '') AS commentId,
                   mention.actorId AS actorId,
                   mentioned.userId AS mentionedUserId,
                   mention.sourceType AS sourceType,
                   mention.createdAt AS createdAt
            ORDER BY mention.createdAt DESC, mention.mentionId
            """;
    static final String SAVE_MENTION = """
            MERGE (content:Content {contentId: $contentId})
            MERGE (mentioned:User {userId: $mentionedUserId})
            MERGE (content)-[mention:MENTIONS {mentionId: $mentionId}]->(mentioned)
            SET mention.commentId = $commentId,
                mention.actorId = $actorId,
                mention.sourceType = $sourceType,
                mention.createdAt = $createdAt
            """;
    static final String DELETE_MENTIONS_FOR_CONTENT = """
            MATCH (:Content {contentId: $contentId})-[mention:MENTIONS]->(:User)
            DELETE mention
            """;
    static final String DELETE_MENTIONS_FOR_CONTENT_SOURCE = """
            MATCH (:Content {contentId: $contentId})-[mention:MENTIONS {sourceType: $sourceType}]->(:User)
            DELETE mention
            """;
    static final String DELETE_MENTIONS_FOR_COMMENT = """
            MATCH (:Content)-[mention:MENTIONS {commentId: $commentId}]->(:User)
            DELETE mention
            """;

    private Neo4jMentionCypher() {
    }
}
