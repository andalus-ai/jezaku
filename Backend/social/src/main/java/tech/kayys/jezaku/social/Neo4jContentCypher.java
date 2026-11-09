package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for social content lifecycle graph records.
 */
final class Neo4jContentCypher {
    static final String READ_CONTENTS = """
            MATCH (content:Content)
            RETURN content.contentId AS contentId,
                   content.ownerId AS ownerId,
                   content.contentType AS contentType,
                   content.scope AS scope,
                   coalesce(content.targetId, '') AS targetId,
                   coalesce(content.caption, '') AS caption,
                   content.createdAt AS createdAt
            ORDER BY content.createdAt DESC, content.contentId
            """;
    static final String READ_CONTENT = """
            MATCH (content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   content.ownerId AS ownerId,
                   content.contentType AS contentType,
                   content.scope AS scope,
                   coalesce(content.targetId, '') AS targetId,
                   coalesce(content.caption, '') AS caption,
                   content.createdAt AS createdAt
            """;
    static final String SAVE_CONTENT = """
            MERGE (owner:User {userId: $ownerId})
            MERGE (content:Content {contentId: $contentId})
            SET content.ownerId = $ownerId,
                content.contentType = $contentType,
                content.scope = $scope,
                content.targetId = $targetId,
                content.caption = $caption,
                content.createdAt = $createdAt
            MERGE (owner)-[created:CREATED]->(content)
            SET created.createdAt = $createdAt
            """;
    static final String DELETE_CONTENT = """
            MATCH (content:Content {contentId: $contentId})
            DETACH DELETE content
            """;

    private Neo4jContentCypher() {
    }
}
