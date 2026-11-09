package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for group, community, membership, join/invite, and moderation graph records.
 */
final class Neo4jCircleCypher {
    static final String READ_GROUPS = """
            MATCH (group:Group)
            RETURN group.groupId AS groupId,
                   group.name AS name,
                   group.visibility AS visibility,
                   group.createdAt AS createdAt
            ORDER BY groupId
            """;
    static final String READ_GROUP = """
            MATCH (group:Group {groupId: $groupId})
            RETURN group.groupId AS groupId,
                   group.name AS name,
                   group.visibility AS visibility,
                   group.createdAt AS createdAt
            """;
    static final String SAVE_GROUP = """
            MERGE (group:Group {groupId: $groupId})
            SET group.name = $name,
                group.visibility = $visibility,
                group.createdAt = $createdAt
            """;
    static final String READ_COMMUNITIES = """
            MATCH (community:Community)
            RETURN community.communityId AS communityId,
                   community.name AS name,
                   community.visibility AS visibility,
                   community.createdAt AS createdAt
            ORDER BY communityId
            """;
    static final String READ_COMMUNITY = """
            MATCH (community:Community {communityId: $communityId})
            RETURN community.communityId AS communityId,
                   community.name AS name,
                   community.visibility AS visibility,
                   community.createdAt AS createdAt
            """;
    static final String SAVE_COMMUNITY = """
            MERGE (community:Community {communityId: $communityId})
            SET community.name = $name,
                community.visibility = $visibility,
                community.createdAt = $createdAt
            """;
    static final String READ_GROUP_MEMBERSHIPS = """
            MATCH (member:User)-[membership:MEMBER_OF]->(group:Group)
            RETURN member.userId AS memberId,
                   group.groupId AS targetId,
                   membership.role AS role,
                   coalesce(membership.createdAt, membership.joinedAt) AS createdAt
            ORDER BY memberId, targetId
            """;
    static final String SAVE_GROUP_MEMBERSHIP = """
            MERGE (member:User {userId: $memberId})
            MERGE (group:Group {groupId: $targetId})
            MERGE (member)-[membership:MEMBER_OF]->(group)
            SET membership.role = $role,
                membership.createdAt = $createdAt,
                membership.joinedAt = $createdAt,
                membership.weight = 0.7
            """;
    static final String DELETE_GROUP_MEMBERSHIP = """
            MATCH (member:User {userId: $memberId})-[membership:MEMBER_OF]->(group:Group {groupId: $targetId})
            DELETE membership
            """;
    static final String READ_COMMUNITY_MEMBERSHIPS = """
            MATCH (member:User)-[membership:MEMBER_OF]->(community:Community)
            RETURN member.userId AS memberId,
                   community.communityId AS targetId,
                   membership.role AS role,
                   coalesce(membership.createdAt, membership.joinedAt) AS createdAt
            ORDER BY memberId, targetId
            """;
    static final String SAVE_COMMUNITY_MEMBERSHIP = """
            MERGE (member:User {userId: $memberId})
            MERGE (community:Community {communityId: $targetId})
            MERGE (member)-[membership:MEMBER_OF]->(community)
            SET membership.role = $role,
                membership.createdAt = $createdAt,
                membership.joinedAt = $createdAt,
                membership.weight = 0.6
            """;
    static final String DELETE_COMMUNITY_MEMBERSHIP = """
            MATCH (member:User {userId: $memberId})-[membership:MEMBER_OF]->(community:Community {communityId: $targetId})
            DELETE membership
            """;
    static final String READ_CIRCLE_MEMBERSHIP_REQUESTS = """
            MATCH (user:User)-[request:JOIN_REQUESTED|INVITED_TO]->(target)
            WHERE target:Group OR target:Community
            RETURN request.requestId AS requestId,
                   coalesce(target.groupId, target.communityId) AS targetId,
                   CASE WHEN target:Group THEN 'group' ELSE 'community' END AS targetType,
                   user.userId AS userId,
                   request.actorUserId AS actorUserId,
                   CASE type(request) WHEN 'JOIN_REQUESTED' THEN 'join_request' ELSE 'invite' END AS requestType,
                   request.status AS status,
                   coalesce(request.message, '') AS message,
                   request.createdAt AS createdAt,
                   request.updatedAt AS updatedAt
            ORDER BY request.createdAt DESC, request.requestId
            """;
    static final String READ_CIRCLE_MEMBERSHIP_REQUEST = """
            MATCH (user:User)-[request:JOIN_REQUESTED|INVITED_TO {requestId: $requestId}]->(target)
            WHERE target:Group OR target:Community
            RETURN request.requestId AS requestId,
                   coalesce(target.groupId, target.communityId) AS targetId,
                   CASE WHEN target:Group THEN 'group' ELSE 'community' END AS targetType,
                   user.userId AS userId,
                   request.actorUserId AS actorUserId,
                   CASE type(request) WHEN 'JOIN_REQUESTED' THEN 'join_request' ELSE 'invite' END AS requestType,
                   request.status AS status,
                   coalesce(request.message, '') AS message,
                   request.createdAt AS createdAt,
                   request.updatedAt AS updatedAt
            """;
    static final String SAVE_GROUP_JOIN_REQUEST = """
            MERGE (user:User {userId: $userId})
            MERGE (target:Group {groupId: $targetId})
            MERGE (user)-[request:JOIN_REQUESTED {requestId: $requestId}]->(target)
            SET request.actorUserId = $actorUserId,
                request.status = $status,
                request.message = $message,
                request.createdAt = $createdAt,
                request.updatedAt = $updatedAt
            """;
    static final String SAVE_COMMUNITY_JOIN_REQUEST = """
            MERGE (user:User {userId: $userId})
            MERGE (target:Community {communityId: $targetId})
            MERGE (user)-[request:JOIN_REQUESTED {requestId: $requestId}]->(target)
            SET request.actorUserId = $actorUserId,
                request.status = $status,
                request.message = $message,
                request.createdAt = $createdAt,
                request.updatedAt = $updatedAt
            """;
    static final String SAVE_GROUP_INVITE = """
            MERGE (user:User {userId: $userId})
            MERGE (target:Group {groupId: $targetId})
            MERGE (user)-[request:INVITED_TO {requestId: $requestId}]->(target)
            SET request.actorUserId = $actorUserId,
                request.status = $status,
                request.message = $message,
                request.createdAt = $createdAt,
                request.updatedAt = $updatedAt
            """;
    static final String SAVE_COMMUNITY_INVITE = """
            MERGE (user:User {userId: $userId})
            MERGE (target:Community {communityId: $targetId})
            MERGE (user)-[request:INVITED_TO {requestId: $requestId}]->(target)
            SET request.actorUserId = $actorUserId,
                request.status = $status,
                request.message = $message,
                request.createdAt = $createdAt,
                request.updatedAt = $updatedAt
            """;
    static final String DELETE_CIRCLE_MEMBERSHIP_REQUEST = """
            MATCH ()-[request:JOIN_REQUESTED|INVITED_TO {requestId: $requestId}]->()
            DELETE request
            """;
    static final String READ_CIRCLE_CONTENT_MODERATIONS = """
            MATCH (actor:User)-[moderation:MODERATED_CONTENT]->(content:Content)
            RETURN moderation.moderationId AS moderationId,
                   content.contentId AS contentId,
                   moderation.targetId AS targetId,
                   moderation.targetType AS targetType,
                   actor.userId AS actorUserId,
                   moderation.action AS action,
                   moderation.status AS status,
                   coalesce(moderation.reason, '') AS reason,
                   moderation.createdAt AS createdAt,
                   moderation.updatedAt AS updatedAt
            ORDER BY moderation.updatedAt DESC, moderation.moderationId
            """;
    static final String READ_CIRCLE_CONTENT_MODERATION = """
            MATCH (actor:User)-[moderation:MODERATED_CONTENT {moderationId: $moderationId}]->(content:Content)
            RETURN moderation.moderationId AS moderationId,
                   content.contentId AS contentId,
                   moderation.targetId AS targetId,
                   moderation.targetType AS targetType,
                   actor.userId AS actorUserId,
                   moderation.action AS action,
                   moderation.status AS status,
                   coalesce(moderation.reason, '') AS reason,
                   moderation.createdAt AS createdAt,
                   moderation.updatedAt AS updatedAt
            """;
    static final String SAVE_CIRCLE_CONTENT_MODERATION = """
            MERGE (actor:User {userId: $actorUserId})
            MERGE (content:Content {contentId: $contentId})
            MERGE (actor)-[moderation:MODERATED_CONTENT {moderationId: $moderationId}]->(content)
            SET moderation.targetId = $targetId,
                moderation.targetType = $targetType,
                moderation.action = $action,
                moderation.status = $status,
                moderation.reason = $reason,
                moderation.createdAt = $createdAt,
                moderation.updatedAt = $updatedAt
            """;
    static final String DELETE_CIRCLE_CONTENT_MODERATIONS = """
            MATCH ()-[moderation:MODERATED_CONTENT]->(content:Content {contentId: $contentId})
            DELETE moderation
            """;

    private Neo4jCircleCypher() {
    }

    static String circleMembershipRequestSaveStatement(CircleMembershipRequestRecord request) {
        if ("group".equals(request.targetType()) && "join_request".equals(request.requestType())) {
            return SAVE_GROUP_JOIN_REQUEST;
        }
        if ("community".equals(request.targetType()) && "join_request".equals(request.requestType())) {
            return SAVE_COMMUNITY_JOIN_REQUEST;
        }
        if ("group".equals(request.targetType()) && "invite".equals(request.requestType())) {
            return SAVE_GROUP_INVITE;
        }
        if ("community".equals(request.targetType()) && "invite".equals(request.requestType())) {
            return SAVE_COMMUNITY_INVITE;
        }
        throw new IllegalArgumentException(
                "Unsupported circle membership request target/request type: "
                        + request.targetType()
                        + "/"
                        + request.requestType());
    }
}
