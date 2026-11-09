package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for hidden content and content report safety records.
 */
final class Neo4jContentSafetyCypher {
    static final String READ_CONTENT_HIDE = """
            MATCH (user:User {userId: $userId})-[hide:HIDDEN_CONTENT]->(content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   coalesce(hide.reason, '') AS reason,
                   hide.createdAt AS createdAt
            """;
    static final String READ_CONTENT_HIDES = """
            MATCH (user:User)-[hide:HIDDEN_CONTENT]->(content:Content {contentId: $contentId})
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   coalesce(hide.reason, '') AS reason,
                   hide.createdAt AS createdAt
            ORDER BY hide.createdAt DESC, user.userId
            """;
    static final String READ_HIDDEN_BY_USER = """
            MATCH (user:User {userId: $userId})-[hide:HIDDEN_CONTENT]->(content:Content)
            RETURN content.contentId AS contentId,
                   user.userId AS userId,
                   coalesce(hide.reason, '') AS reason,
                   hide.createdAt AS createdAt
            ORDER BY hide.createdAt DESC, content.contentId
            """;
    static final String SAVE_CONTENT_HIDE = """
            MERGE (user:User {userId: $userId})
            MERGE (content:Content {contentId: $contentId})
            MERGE (user)-[hide:HIDDEN_CONTENT]->(content)
            SET hide.reason = $reason,
                hide.createdAt = $createdAt
            """;
    static final String DELETE_CONTENT_HIDE = """
            MATCH (user:User {userId: $userId})-[hide:HIDDEN_CONTENT]->(content:Content {contentId: $contentId})
            DELETE hide
            """;
    static final String READ_CONTENT_REPORT = """
            MATCH (reporter:User)-[report:REPORTED {reportId: $reportId}]->(content:Content)
            RETURN report.reportId AS reportId,
                   content.contentId AS contentId,
                   reporter.userId AS reporterId,
                   report.reason AS reason,
                   coalesce(report.detail, '') AS detail,
                   report.status AS status,
                   report.createdAt AS createdAt,
                   report.updatedAt AS updatedAt
            """;
    static final String READ_CONTENT_REPORTS = """
            MATCH (reporter:User)-[report:REPORTED]->(content:Content)
            RETURN report.reportId AS reportId,
                   content.contentId AS contentId,
                   reporter.userId AS reporterId,
                   report.reason AS reason,
                   coalesce(report.detail, '') AS detail,
                   report.status AS status,
                   report.createdAt AS createdAt,
                   report.updatedAt AS updatedAt
            ORDER BY report.createdAt DESC, report.reportId
            """;
    static final String SAVE_CONTENT_REPORT = """
            MERGE (reporter:User {userId: $reporterId})
            MERGE (content:Content {contentId: $contentId})
            MERGE (reporter)-[report:REPORTED {reportId: $reportId}]->(content)
            SET report.reason = $reason,
                report.detail = $detail,
                report.status = $status,
                report.createdAt = $createdAt,
                report.updatedAt = $updatedAt
            """;
    static final String DELETE_CONTENT_REPORTS = """
            MATCH ()-[report:REPORTED]->(:Content {contentId: $contentId})
            DELETE report
            """;

    private Neo4jContentSafetyCypher() {
    }
}
