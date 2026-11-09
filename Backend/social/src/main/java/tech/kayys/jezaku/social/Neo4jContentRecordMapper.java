package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;

import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jRecordValues.instant;
import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;

/**
 * Maps Neo4j content and interaction rows into social graph records and persistence parameters.
 */
final class Neo4jContentRecordMapper {
    SocialContentRecord content(Record record) {
        return new SocialContentRecord(
                record.get("contentId").asString(),
                record.get("ownerId").asString(),
                record.get("contentType").asString(),
                record.get("scope").asString(),
                record.get("targetId").asString(),
                record.get("caption").asString(),
                instant(record, "createdAt"));
    }

    Map<String, Object> contentParameters(SocialContentRecord content) {
        return Map.of(
                "contentId", content.contentId(),
                "ownerId", content.ownerId(),
                "contentType", content.contentType(),
                "scope", content.scope(),
                "targetId", content.targetId(),
                "caption", content.caption(),
                "createdAt", iso(content.createdAt()));
    }

    SocialReactionRecord reaction(Record record) {
        return new SocialReactionRecord(
                record.get("contentId").asString(),
                record.get("userId").asString(),
                record.get("reactionType").asString(),
                instant(record, "createdAt"));
    }

    SocialCommentRecord comment(Record record) {
        return new SocialCommentRecord(
                record.get("commentId").asString(),
                record.get("contentId").asString(),
                record.get("authorId").asString(),
                record.get("text").asString(),
                record.get("parentCommentId").asString(),
                instant(record, "createdAt"));
    }

    SocialContentTagRecord contentTag(Record record) {
        return new SocialContentTagRecord(
                record.get("contentId").asString(),
                record.get("tag").asString(),
                instant(record, "createdAt"));
    }

    SocialTagFollowRecord tagFollow(Record record) {
        return new SocialTagFollowRecord(
                record.get("userId").asString(),
                record.get("tag").asString(),
                instant(record, "createdAt"));
    }

    SocialCommentReactionRecord commentReaction(Record record) {
        return new SocialCommentReactionRecord(
                record.get("commentId").asString(),
                record.get("userId").asString(),
                record.get("reactionType").asString(),
                instant(record, "createdAt"));
    }

    SocialSaveRecord save(Record record) {
        return new SocialSaveRecord(
                record.get("contentId").asString(),
                record.get("userId").asString(),
                instant(record, "createdAt"));
    }

    SocialShareRecord share(Record record) {
        return new SocialShareRecord(
                record.get("shareId").asString(),
                record.get("contentId").asString(),
                record.get("userId").asString(),
                record.get("message").asString(),
                instant(record, "createdAt"));
    }

    SocialContentHideRecord contentHide(Record record) {
        return new SocialContentHideRecord(
                record.get("contentId").asString(),
                record.get("userId").asString(),
                record.get("reason").asString(),
                instant(record, "createdAt"));
    }

    SocialContentReportRecord contentReport(Record record) {
        return new SocialContentReportRecord(
                record.get("reportId").asString(),
                record.get("contentId").asString(),
                record.get("reporterId").asString(),
                record.get("reason").asString(),
                record.get("detail").asString(),
                record.get("status").asString(),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    SocialMentionRecord mention(Record record) {
        return new SocialMentionRecord(
                record.get("mentionId").asString(),
                record.get("contentId").asString(),
                record.get("commentId").asString(),
                record.get("actorId").asString(),
                record.get("mentionedUserId").asString(),
                record.get("sourceType").asString(),
                instant(record, "createdAt"));
    }
}
