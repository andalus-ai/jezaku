package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;

import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jRecordValues.instant;
import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;

/**
 * Maps Neo4j relationship and profile rows into social graph records and Cypher parameter maps.
 */
final class Neo4jRelationshipRecordMapper {
    FriendRequestRecord friendRequest(Record record) {
        return new FriendRequestRecord(
                record.get("id").asString(),
                record.get("fromUserId").asString(),
                record.get("toUserId").asString(),
                record.get("message").asString(),
                record.get("status").asString(),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    Map<String, Object> friendRequestParameters(FriendRequestRecord request) {
        return Map.of(
                "id", request.id(),
                "fromUserId", request.fromUserId(),
                "toUserId", request.toUserId(),
                "message", request.message(),
                "status", request.status(),
                "createdAt", iso(request.createdAt()),
                "updatedAt", iso(request.updatedAt()));
    }

    FriendshipRecord friendship(Record record) {
        return new FriendshipRecord(
                record.get("firstUserId").asString(),
                record.get("secondUserId").asString(),
                instant(record, "createdAt"));
    }

    CloseFriendRecord closeFriend(Record record) {
        return new CloseFriendRecord(
                record.get("ownerId").asString(),
                record.get("friendId").asString(),
                instant(record, "createdAt"));
    }

    SocialUserFollowRecord userFollow(Record record) {
        return new SocialUserFollowRecord(
                record.get("followerId").asString(),
                record.get("followedUserId").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> userFollowParameters(SocialUserFollowRecord follow) {
        return Map.of(
                "followerId", follow.followerId(),
                "followedUserId", follow.followedUserId(),
                "createdAt", iso(follow.createdAt()));
    }

    SocialUserFollowRequestRecord userFollowRequest(Record record) {
        return new SocialUserFollowRequestRecord(
                record.get("followerId").asString(),
                record.get("followedUserId").asString(),
                record.get("status").asString(),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    Map<String, Object> userFollowRequestParameters(SocialUserFollowRequestRecord request) {
        return Map.of(
                "followerId", request.followerId(),
                "followedUserId", request.followedUserId(),
                "status", request.status(),
                "createdAt", iso(request.createdAt()),
                "updatedAt", iso(request.updatedAt()));
    }

    SocialUserProfileRecord userProfile(Record record) {
        return new SocialUserProfileRecord(
                record.get("userId").asString(),
                record.get("handle").asString(),
                record.get("displayName").asString(),
                record.get("bio").asString(),
                record.get("avatarUrl").asString(),
                record.get("websiteUrl").asString(),
                record.get("locationLabel").asString(),
                record.get("profileVisibility").asString(),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    Map<String, Object> userProfileParameters(SocialUserProfileRecord profile) {
        return Map.of(
                "userId", profile.userId(),
                "handle", profile.handle(),
                "displayName", profile.displayName(),
                "bio", profile.bio(),
                "avatarUrl", profile.avatarUrl(),
                "websiteUrl", profile.websiteUrl(),
                "locationLabel", profile.locationLabel(),
                "profileVisibility", profile.profileVisibility(),
                "createdAt", iso(profile.createdAt()),
                "updatedAt", iso(profile.updatedAt()));
    }

    BlockRecord block(Record record) {
        return new BlockRecord(
                record.get("userId").asString(),
                record.get("blockedUserId").asString(),
                record.get("reason").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> blockParameters(BlockRecord block) {
        return Map.of(
                "userId", block.userId(),
                "blockedUserId", block.blockedUserId(),
                "reason", block.reason(),
                "createdAt", iso(block.createdAt()));
    }

    SocialMuteRecord mute(Record record) {
        return new SocialMuteRecord(
                record.get("userId").asString(),
                record.get("targetType").asString(),
                record.get("targetId").asString(),
                record.get("reason").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> muteParameters(SocialMuteRecord mute) {
        return Map.of(
                "userId", mute.userId(),
                "targetType", mute.targetType(),
                "targetId", mute.targetId(),
                "reason", mute.reason(),
                "createdAt", iso(mute.createdAt()));
    }

    FamilyLinkRecord familyLink(Record record) {
        return new FamilyLinkRecord(
                record.get("firstUserId").asString(),
                record.get("secondUserId").asString(),
                record.get("relationship").asString(),
                instant(record, "createdAt"));
    }
}
