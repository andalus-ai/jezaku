package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;

import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jRecordValues.instant;
import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;

/**
 * Maps Neo4j group, community, membership, and circle workflow rows into social graph records.
 */
final class Neo4jCircleRecordMapper {
    SocialGroupRecord group(Record record) {
        return new SocialGroupRecord(
                record.get("groupId").asString(),
                record.get("name").asString(),
                record.get("visibility").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> groupParameters(SocialGroupRecord group) {
        return Map.of(
                "groupId", group.groupId(),
                "name", group.name(),
                "visibility", group.visibility(),
                "createdAt", iso(group.createdAt()));
    }

    SocialCommunityRecord community(Record record) {
        return new SocialCommunityRecord(
                record.get("communityId").asString(),
                record.get("name").asString(),
                record.get("visibility").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> communityParameters(SocialCommunityRecord community) {
        return Map.of(
                "communityId", community.communityId(),
                "name", community.name(),
                "visibility", community.visibility(),
                "createdAt", iso(community.createdAt()));
    }

    MembershipRecord membership(Record record) {
        return new MembershipRecord(
                record.get("memberId").asString(),
                record.get("targetId").asString(),
                record.get("role").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> membershipParameters(MembershipRecord membership) {
        return Map.of(
                "memberId", membership.memberId(),
                "targetId", membership.targetId(),
                "role", membership.role(),
                "createdAt", iso(membership.createdAt()));
    }

    CircleMembershipRequestRecord circleMembershipRequest(Record record) {
        return new CircleMembershipRequestRecord(
                record.get("requestId").asString(),
                record.get("targetId").asString(),
                record.get("targetType").asString(),
                record.get("userId").asString(),
                record.get("actorUserId").asString(),
                record.get("requestType").asString(),
                record.get("status").asString(),
                record.get("message").asString(),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    Map<String, Object> circleMembershipRequestParameters(CircleMembershipRequestRecord request) {
        return Map.of(
                "requestId", request.requestId(),
                "targetId", request.targetId(),
                "userId", request.userId(),
                "actorUserId", request.actorUserId(),
                "status", request.status(),
                "message", request.message(),
                "createdAt", iso(request.createdAt()),
                "updatedAt", iso(request.updatedAt()));
    }

    CircleContentModerationRecord circleContentModeration(Record record) {
        return new CircleContentModerationRecord(
                record.get("moderationId").asString(),
                record.get("contentId").asString(),
                record.get("targetId").asString(),
                record.get("targetType").asString(),
                record.get("actorUserId").asString(),
                record.get("action").asString(),
                record.get("status").asString(),
                record.get("reason").asString(),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    Map<String, Object> circleContentModerationParameters(CircleContentModerationRecord moderation) {
        return Map.of(
                "moderationId", moderation.moderationId(),
                "contentId", moderation.contentId(),
                "targetId", moderation.targetId(),
                "targetType", moderation.targetType(),
                "actorUserId", moderation.actorUserId(),
                "action", moderation.action(),
                "status", moderation.status(),
                "reason", moderation.reason(),
                "createdAt", iso(moderation.createdAt()),
                "updatedAt", iso(moderation.updatedAt()));
    }
}
