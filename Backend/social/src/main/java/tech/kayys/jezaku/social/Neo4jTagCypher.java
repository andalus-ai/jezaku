package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for content tags and topic follow graph records.
 */
final class Neo4jTagCypher {
    static final String READ_TAGS = """
            MATCH (content:Content)-[tagged:TAGGED_WITH]->(topic:Topic)
            RETURN content.contentId AS contentId,
                   topic.tag AS tag,
                   tagged.createdAt AS createdAt
            ORDER BY tagged.createdAt DESC, content.contentId, tag
            """;
    static final String READ_CONTENT_TAGS = """
            MATCH (content:Content {contentId: $contentId})-[tagged:TAGGED_WITH]->(topic:Topic)
            RETURN content.contentId AS contentId,
                   topic.tag AS tag,
                   tagged.createdAt AS createdAt
            ORDER BY tag
            """;
    static final String READ_TAGGED_CONTENT = """
            MATCH (content:Content)-[tagged:TAGGED_WITH]->(topic:Topic {tag: $tag})
            RETURN content.contentId AS contentId,
                   topic.tag AS tag,
                   tagged.createdAt AS createdAt
            ORDER BY tagged.createdAt DESC, content.contentId
            """;
    static final String SAVE_CONTENT_TAG = """
            MERGE (content:Content {contentId: $contentId})
            MERGE (topic:Topic {tag: $tag})
            MERGE (content)-[tagged:TAGGED_WITH]->(topic)
            SET tagged.createdAt = $createdAt
            """;
    static final String DELETE_CONTENT_TAGS = """
            MATCH (content:Content {contentId: $contentId})-[tagged:TAGGED_WITH]->(:Topic)
            DELETE tagged
            """;
    static final String READ_TAG_FOLLOW = """
            MATCH (user:User {userId: $userId})-[follow:FOLLOWS_TOPIC]->(topic:Topic {tag: $tag})
            RETURN user.userId AS userId,
                   topic.tag AS tag,
                   follow.createdAt AS createdAt
            """;
    static final String READ_ALL_TAG_FOLLOWS = """
            MATCH (user:User)-[follow:FOLLOWS_TOPIC]->(topic:Topic)
            RETURN user.userId AS userId,
                   topic.tag AS tag,
                   follow.createdAt AS createdAt
            ORDER BY topic.tag, user.userId
            """;
    static final String READ_TAG_FOLLOWS = """
            MATCH (user:User)-[follow:FOLLOWS_TOPIC]->(topic:Topic {tag: $tag})
            RETURN user.userId AS userId,
                   topic.tag AS tag,
                   follow.createdAt AS createdAt
            ORDER BY follow.createdAt DESC, user.userId
            """;
    static final String READ_TAG_FOLLOWS_BY_USER = """
            MATCH (user:User {userId: $userId})-[follow:FOLLOWS_TOPIC]->(topic:Topic)
            RETURN user.userId AS userId,
                   topic.tag AS tag,
                   follow.createdAt AS createdAt
            ORDER BY topic.tag
            """;
    static final String SAVE_TAG_FOLLOW = """
            MERGE (user:User {userId: $userId})
            MERGE (topic:Topic {tag: $tag})
            MERGE (user)-[follow:FOLLOWS_TOPIC]->(topic)
            SET follow.createdAt = $createdAt
            """;
    static final String DELETE_TAG_FOLLOW = """
            MATCH (user:User {userId: $userId})-[follow:FOLLOWS_TOPIC]->(topic:Topic {tag: $tag})
            DELETE follow
            """;

    private Neo4jTagCypher() {
    }
}
