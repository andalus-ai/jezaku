package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for relationship, profile, block, mute, and family graph records.
 */
final class Neo4jRelationshipCypher {
    static final String READ_FRIEND_REQUESTS = """
            MATCH (from:User)-[request:FRIEND_REQUEST]->(to:User)
            RETURN request.id AS id,
                   from.userId AS fromUserId,
                   to.userId AS toUserId,
                   coalesce(request.message, '') AS message,
                   request.status AS status,
                   request.createdAt AS createdAt,
                   request.updatedAt AS updatedAt
            ORDER BY request.createdAt DESC, request.id
            """;
    static final String READ_FRIEND_REQUEST = """
            MATCH (from:User)-[request:FRIEND_REQUEST {id: $requestId}]->(to:User)
            RETURN request.id AS id,
                   from.userId AS fromUserId,
                   to.userId AS toUserId,
                   coalesce(request.message, '') AS message,
                   request.status AS status,
                   request.createdAt AS createdAt,
                   request.updatedAt AS updatedAt
            """;
    static final String SAVE_FRIEND_REQUEST = """
            MERGE (from:User {userId: $fromUserId})
            MERGE (to:User {userId: $toUserId})
            MERGE (from)-[request:FRIEND_REQUEST {id: $id}]->(to)
            SET request.message = $message,
                request.status = $status,
                request.createdAt = $createdAt,
                request.updatedAt = $updatedAt
            """;
    static final String DELETE_FRIEND_REQUEST = """
            MATCH ()-[request:FRIEND_REQUEST {id: $requestId}]->()
            DELETE request
            """;
    static final String READ_FRIENDSHIPS = """
            MATCH (first:User)-[friend:FRIEND]-(second:User)
            WHERE first.userId < second.userId
            RETURN first.userId AS firstUserId,
                   second.userId AS secondUserId,
                   coalesce(friend.createdAt, friend.since) AS createdAt
            ORDER BY firstUserId, secondUserId
            """;
    static final String SAVE_FRIENDSHIP = """
            MERGE (first:User {userId: $firstUserId})
            MERGE (second:User {userId: $secondUserId})
            MERGE (first)-[friend:FRIEND]->(second)
            SET friend.createdAt = $createdAt,
                friend.since = $createdAt,
                friend.weight = 1.0
            """;
    static final String DELETE_FRIENDSHIP = """
            MATCH (first:User {userId: $firstUserId})-[friend:FRIEND]-(second:User {userId: $secondUserId})
            DELETE friend
            """;
    static final String READ_CLOSE_FRIENDS = """
            MATCH (owner:User)-[close:CLOSE_FRIEND]->(friend:User)
            RETURN owner.userId AS ownerId,
                   friend.userId AS friendId,
                   close.createdAt AS createdAt
            ORDER BY ownerId, friendId
            """;
    static final String SAVE_CLOSE_FRIEND = """
            MERGE (owner:User {userId: $ownerId})
            MERGE (friend:User {userId: $friendId})
            MERGE (owner)-[close:CLOSE_FRIEND]->(friend)
            SET close.createdAt = $createdAt,
                close.weight = 1.2
            """;
    static final String DELETE_CLOSE_FRIEND = """
            MATCH (owner:User {userId: $ownerId})-[close:CLOSE_FRIEND]->(friend:User {userId: $friendId})
            DELETE close
            """;
    static final String READ_USER_FOLLOW = """
            MATCH (follower:User {userId: $followerId})-[follow:FOLLOWS_USER]->(followed:User {userId: $followedUserId})
            RETURN follower.userId AS followerId,
                   followed.userId AS followedUserId,
                   follow.createdAt AS createdAt
            """;
    static final String READ_USER_FOLLOWS = """
            MATCH (follower:User)-[follow:FOLLOWS_USER]->(followed:User)
            RETURN follower.userId AS followerId,
                   followed.userId AS followedUserId,
                   follow.createdAt AS createdAt
            ORDER BY follow.createdAt DESC, followerId, followedUserId
            """;
    static final String READ_FOLLOWERS = """
            MATCH (follower:User)-[follow:FOLLOWS_USER]->(followed:User {userId: $userId})
            RETURN follower.userId AS followerId,
                   followed.userId AS followedUserId,
                   follow.createdAt AS createdAt
            ORDER BY follow.createdAt DESC, followerId
            """;
    static final String READ_FOLLOWING = """
            MATCH (follower:User {userId: $userId})-[follow:FOLLOWS_USER]->(followed:User)
            RETURN follower.userId AS followerId,
                   followed.userId AS followedUserId,
                   follow.createdAt AS createdAt
            ORDER BY follow.createdAt DESC, followedUserId
            """;
    static final String SAVE_USER_FOLLOW = """
            MERGE (follower:User {userId: $followerId})
            MERGE (followed:User {userId: $followedUserId})
            MERGE (follower)-[follow:FOLLOWS_USER]->(followed)
            SET follow.createdAt = $createdAt
            """;
    static final String DELETE_USER_FOLLOW = """
            MATCH (follower:User {userId: $followerId})-[follow:FOLLOWS_USER]->(followed:User {userId: $followedUserId})
            DELETE follow
            """;
    static final String READ_USER_FOLLOW_REQUEST = """
            MATCH (follower:User {userId: $followerId})-[request:FOLLOW_REQUESTED]->(followed:User {userId: $followedUserId})
            RETURN follower.userId AS followerId,
                   followed.userId AS followedUserId,
                   request.status AS status,
                   request.createdAt AS createdAt,
                   request.updatedAt AS updatedAt
            """;
    static final String READ_USER_FOLLOW_REQUESTS = """
            MATCH (follower:User)-[request:FOLLOW_REQUESTED]->(followed:User)
            RETURN follower.userId AS followerId,
                   followed.userId AS followedUserId,
                   request.status AS status,
                   request.createdAt AS createdAt,
                   request.updatedAt AS updatedAt
            ORDER BY request.updatedAt DESC, followerId, followedUserId
            """;
    static final String SAVE_USER_FOLLOW_REQUEST = """
            MERGE (follower:User {userId: $followerId})
            MERGE (followed:User {userId: $followedUserId})
            MERGE (follower)-[request:FOLLOW_REQUESTED]->(followed)
            SET request.status = $status,
                request.createdAt = $createdAt,
                request.updatedAt = $updatedAt
            """;
    static final String DELETE_USER_FOLLOW_REQUEST = """
            MATCH (follower:User {userId: $followerId})-[request:FOLLOW_REQUESTED]->(followed:User {userId: $followedUserId})
            DELETE request
            """;
    static final String READ_USER_PROFILE = """
            MATCH (user:User {userId: $userId})
            WHERE user.profileUpdatedAt IS NOT NULL
            RETURN user.userId AS userId,
                   user.handle AS handle,
                   coalesce(user.displayName, user.userId) AS displayName,
                   coalesce(user.bio, '') AS bio,
                   coalesce(user.avatarUrl, '') AS avatarUrl,
                   coalesce(user.websiteUrl, '') AS websiteUrl,
                   coalesce(user.locationLabel, '') AS locationLabel,
                   coalesce(user.profileVisibility, 'public') AS profileVisibility,
                   user.profileCreatedAt AS createdAt,
                   user.profileUpdatedAt AS updatedAt
            """;
    static final String READ_USER_PROFILE_BY_HANDLE = """
            MATCH (user:User {handle: $handle})
            WHERE user.profileUpdatedAt IS NOT NULL
            RETURN user.userId AS userId,
                   user.handle AS handle,
                   coalesce(user.displayName, user.userId) AS displayName,
                   coalesce(user.bio, '') AS bio,
                   coalesce(user.avatarUrl, '') AS avatarUrl,
                   coalesce(user.websiteUrl, '') AS websiteUrl,
                   coalesce(user.locationLabel, '') AS locationLabel,
                   coalesce(user.profileVisibility, 'public') AS profileVisibility,
                   user.profileCreatedAt AS createdAt,
                   user.profileUpdatedAt AS updatedAt
            """;
    static final String READ_USER_PROFILES = """
            MATCH (user:User)
            WHERE user.profileUpdatedAt IS NOT NULL
            RETURN user.userId AS userId,
                   user.handle AS handle,
                   coalesce(user.displayName, user.userId) AS displayName,
                   coalesce(user.bio, '') AS bio,
                   coalesce(user.avatarUrl, '') AS avatarUrl,
                   coalesce(user.websiteUrl, '') AS websiteUrl,
                   coalesce(user.locationLabel, '') AS locationLabel,
                   coalesce(user.profileVisibility, 'public') AS profileVisibility,
                   user.profileCreatedAt AS createdAt,
                   user.profileUpdatedAt AS updatedAt
            ORDER BY displayName, userId
            """;
    static final String SAVE_USER_PROFILE = """
            MERGE (user:User {userId: $userId})
            SET user.handle = $handle,
                user.displayName = $displayName,
                user.bio = $bio,
                user.avatarUrl = $avatarUrl,
                user.websiteUrl = $websiteUrl,
                user.locationLabel = $locationLabel,
                user.profileVisibility = $profileVisibility,
                user.profileCreatedAt = coalesce(user.profileCreatedAt, $createdAt),
                user.profileUpdatedAt = $updatedAt
            """;
    static final String READ_BLOCKS = """
            MATCH (user:User)-[block:BLOCKED]->(blocked:User)
            RETURN user.userId AS userId,
                   blocked.userId AS blockedUserId,
                   coalesce(block.reason, '') AS reason,
                   block.createdAt AS createdAt
            ORDER BY userId, blockedUserId
            """;
    static final String SAVE_BLOCK = """
            MERGE (user:User {userId: $userId})
            MERGE (blocked:User {userId: $blockedUserId})
            MERGE (user)-[block:BLOCKED]->(blocked)
            SET block.reason = $reason,
                block.createdAt = $createdAt
            """;
    static final String DELETE_BLOCK = """
            MATCH (user:User {userId: $userId})-[block:BLOCKED]->(blocked:User {userId: $blockedUserId})
            DELETE block
            """;
    static final String READ_MUTE = """
            MATCH (user:User {userId: $userId})-[mute:MUTED]->()
            WHERE mute.targetType = $targetType AND mute.targetId = $targetId
            RETURN user.userId AS userId,
                   mute.targetType AS targetType,
                   mute.targetId AS targetId,
                   coalesce(mute.reason, '') AS reason,
                   mute.createdAt AS createdAt
            """;
    static final String READ_MUTES = """
            MATCH (user:User)-[mute:MUTED]->()
            RETURN user.userId AS userId,
                   mute.targetType AS targetType,
                   mute.targetId AS targetId,
                   coalesce(mute.reason, '') AS reason,
                   mute.createdAt AS createdAt
            ORDER BY mute.createdAt DESC, userId, targetType, targetId
            """;
    static final String READ_MUTES_BY_USER = """
            MATCH (user:User {userId: $userId})-[mute:MUTED]->()
            RETURN user.userId AS userId,
                   mute.targetType AS targetType,
                   mute.targetId AS targetId,
                   coalesce(mute.reason, '') AS reason,
                   mute.createdAt AS createdAt
            ORDER BY mute.createdAt DESC, targetType, targetId
            """;
    static final String SAVE_USER_MUTE = """
            MERGE (user:User {userId: $userId})
            MERGE (target:User {userId: $targetId})
            MERGE (user)-[mute:MUTED]->(target)
            SET mute.targetType = $targetType,
                mute.targetId = $targetId,
                mute.reason = $reason,
                mute.createdAt = $createdAt
            """;
    static final String SAVE_GROUP_MUTE = """
            MERGE (user:User {userId: $userId})
            MERGE (target:Group {groupId: $targetId})
            MERGE (user)-[mute:MUTED]->(target)
            SET mute.targetType = $targetType,
                mute.targetId = $targetId,
                mute.reason = $reason,
                mute.createdAt = $createdAt
            """;
    static final String SAVE_COMMUNITY_MUTE = """
            MERGE (user:User {userId: $userId})
            MERGE (target:Community {communityId: $targetId})
            MERGE (user)-[mute:MUTED]->(target)
            SET mute.targetType = $targetType,
                mute.targetId = $targetId,
                mute.reason = $reason,
                mute.createdAt = $createdAt
            """;
    static final String DELETE_MUTE = """
            MATCH (user:User {userId: $userId})-[mute:MUTED]->()
            WHERE mute.targetType = $targetType AND mute.targetId = $targetId
            DELETE mute
            """;
    static final String READ_FAMILY_LINKS = """
            MATCH (first:User)-[family:FAMILY]-(second:User)
            WHERE first.userId < second.userId
            RETURN first.userId AS firstUserId,
                   second.userId AS secondUserId,
                   family.relationship AS relationship,
                   coalesce(family.createdAt, family.since) AS createdAt
            ORDER BY firstUserId, secondUserId
            """;
    static final String SAVE_FAMILY_LINK = """
            MERGE (first:User {userId: $firstUserId})
            MERGE (second:User {userId: $secondUserId})
            MERGE (first)-[family:FAMILY]->(second)
            SET family.relationship = $relationship,
                family.createdAt = $createdAt,
                family.since = $createdAt,
                family.weight = 1.15
            """;
    static final String DELETE_FAMILY_LINK = """
            MATCH (first:User {userId: $firstUserId})-[family:FAMILY]-(second:User {userId: $secondUserId})
            DELETE family
            """;

    private Neo4jRelationshipCypher() {
    }

    static String muteSaveStatement(SocialMuteRecord mute) {
        return switch (mute.targetType()) {
            case "user" -> SAVE_USER_MUTE;
            case "group" -> SAVE_GROUP_MUTE;
            case "community" -> SAVE_COMMUNITY_MUTE;
            default -> throw new IllegalArgumentException("Unsupported mute targetType: " + mute.targetType());
        };
    }
}
