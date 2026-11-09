package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for reactions, comments, saves, and shares.
 */
final class Neo4jEngagementCypher {
    static final String READ_REACTION = """
            MATCH (user:User {userId: $userId})-[reaction:REACTED_TO]->(content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   reaction.reactionType AS reactionType,
                   reaction.createdAt AS createdAt
            """;
    static final String READ_REACTIONS = """
            MATCH (user:User)-[reaction:REACTED_TO]->(content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   reaction.reactionType AS reactionType,
                   reaction.createdAt AS createdAt
            ORDER BY reaction.createdAt DESC, user.userId
            """;
    static final String SAVE_REACTION = """
            MERGE (user:User {userId: $userId})
            MERGE (content:Content {contentId: $contentId})
            MERGE (user)-[reaction:REACTED_TO]->(content)
            SET reaction.reactionType = $reactionType,
                reaction.createdAt = $createdAt
            """;
    static final String DELETE_REACTION = """
            MATCH (user:User {userId: $userId})-[reaction:REACTED_TO]->(content:Content {contentId: $contentId})
            DELETE reaction
            """;
    static final String READ_COMMENT = """
            MATCH (comment:Comment {commentId: $commentId})
            RETURN comment.commentId AS commentId,
                   comment.contentId AS contentId,
                   comment.authorId AS authorId,
                   comment.text AS text,
                   coalesce(comment.parentCommentId, '') AS parentCommentId,
                   comment.createdAt AS createdAt
            """;
    static final String READ_COMMENTS = """
            MATCH (comment:Comment {contentId: $contentId})
            RETURN comment.commentId AS commentId,
                   comment.contentId AS contentId,
                   comment.authorId AS authorId,
                   comment.text AS text,
                   coalesce(comment.parentCommentId, '') AS parentCommentId,
                   comment.createdAt AS createdAt
            ORDER BY comment.createdAt ASC, comment.commentId
            """;
    static final String SAVE_COMMENT = """
            MERGE (author:User {userId: $authorId})
            MERGE (content:Content {contentId: $contentId})
            MERGE (comment:Comment {commentId: $commentId})
            SET comment.contentId = $contentId,
                comment.authorId = $authorId,
                comment.text = $text,
                comment.parentCommentId = $parentCommentId,
                comment.createdAt = $createdAt
            MERGE (author)-[wrote:WROTE]->(comment)
            SET wrote.createdAt = $createdAt
            MERGE (comment)-[onContent:ON_CONTENT]->(content)
            SET onContent.createdAt = $createdAt
            WITH comment
            OPTIONAL MATCH (comment)-[oldReply:REPLIED_TO]->()
            DELETE oldReply
            WITH comment
            CALL {
                WITH comment
                WITH comment WHERE $parentCommentId <> ''
                MATCH (parent:Comment {commentId: $parentCommentId})
                MERGE (comment)-[reply:REPLIED_TO]->(parent)
                SET reply.createdAt = $createdAt
                RETURN count(*) AS replyEdgeCount
            }
            RETURN replyEdgeCount
            """;
    static final String DELETE_COMMENT = """
            MATCH (comment:Comment {commentId: $commentId})
            DETACH DELETE comment
            """;
    static final String READ_COMMENT_REACTION = """
            MATCH (user:User {userId: $userId})-[reaction:REACTED_TO_COMMENT]->(comment:Comment {commentId: $commentId})
            RETURN comment.commentId AS commentId,
                   user.userId AS userId,
                   reaction.reactionType AS reactionType,
                   reaction.createdAt AS createdAt
            """;
    static final String READ_COMMENT_REACTIONS = """
            MATCH (user:User)-[reaction:REACTED_TO_COMMENT]->(comment:Comment {commentId: $commentId})
            RETURN comment.commentId AS commentId,
                   user.userId AS userId,
                   reaction.reactionType AS reactionType,
                   reaction.createdAt AS createdAt
            ORDER BY reaction.createdAt DESC, user.userId
            """;
    static final String SAVE_COMMENT_REACTION = """
            MERGE (user:User {userId: $userId})
            MERGE (comment:Comment {commentId: $commentId})
            MERGE (user)-[reaction:REACTED_TO_COMMENT]->(comment)
            SET reaction.reactionType = $reactionType,
                reaction.createdAt = $createdAt
            """;
    static final String DELETE_COMMENT_REACTION = """
            MATCH (user:User {userId: $userId})-[reaction:REACTED_TO_COMMENT]->(comment:Comment {commentId: $commentId})
            DELETE reaction
            """;
    static final String READ_SAVE = """
            MATCH (user:User {userId: $userId})-[save:SAVED]->(content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   save.createdAt AS createdAt
            """;
    static final String READ_SAVES = """
            MATCH (user:User)-[save:SAVED]->(content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   save.createdAt AS createdAt
            ORDER BY save.createdAt DESC, user.userId
            """;
    static final String READ_SAVED_BY_USER = """
            MATCH (user:User {userId: $userId})-[save:SAVED]->(content:Content)
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   save.createdAt AS createdAt
            ORDER BY save.createdAt DESC, content.contentId
            """;
    static final String SAVE_SAVE = """
            MERGE (user:User {userId: $userId})
            MERGE (content:Content {contentId: $contentId})
            MERGE (user)-[save:SAVED]->(content)
            SET save.createdAt = $createdAt
            """;
    static final String DELETE_SAVE = """
            MATCH (user:User {userId: $userId})-[save:SAVED]->(content:Content {contentId: $contentId})
            DELETE save
            """;
    static final String READ_SHARE = """
            MATCH (user:User)-[share:SHARED {shareId: $shareId}]->(content:Content)
            RETURN share.shareId AS shareId,
                   content.contentId AS contentId,
                   user.userId AS userId,
                   coalesce(share.message, '') AS message,
                   share.createdAt AS createdAt
            """;
    static final String READ_SHARES = """
            MATCH (user:User)-[share:SHARED]->(content:Content {contentId: $contentId})
            RETURN share.shareId AS shareId,
                   content.contentId AS contentId,
                   user.userId AS userId,
                   coalesce(share.message, '') AS message,
                   share.createdAt AS createdAt
            ORDER BY share.createdAt DESC, share.shareId
            """;
    static final String SAVE_SHARE = """
            MERGE (user:User {userId: $userId})
            MERGE (content:Content {contentId: $contentId})
            CREATE (user)-[share:SHARED]->(content)
            SET share.shareId = $shareId,
                share.message = $message,
                share.createdAt = $createdAt
            """;
    static final String DELETE_SHARE = """
            MATCH ()-[share:SHARED {shareId: $shareId}]->()
            DELETE share
            """;

    private Neo4jEngagementCypher() {
    }
}
