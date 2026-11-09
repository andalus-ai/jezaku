package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.Values;
import org.neo4j.driver.internal.InternalRecord;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class Neo4jContentRecordMapperTest {
    private static final Instant NOW = Instant.parse("2026-06-09T04:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-09T05:00:00Z");

    private final Neo4jContentRecordMapper mapper = new Neo4jContentRecordMapper();

    @Test
    void mapsContentRecordsAndParameters() {
        SocialContentRecord content = mapper.content(record(contentFields()));

        assertEquals("content_a", content.contentId());
        assertEquals("owner_a", content.ownerId());
        assertEquals("post", content.contentType());
        assertEquals("friends", content.scope());
        assertEquals("group_a", content.targetId());
        assertEquals("caption", content.caption());
        assertEquals(NOW, content.createdAt());

        Map<String, Object> parameters = mapper.contentParameters(content);

        assertEquals("content_a", parameters.get("contentId"));
        assertEquals("owner_a", parameters.get("ownerId"));
        assertEquals("friends", parameters.get("scope"));
        assertEquals("2026-06-09T04:00:00Z", parameters.get("createdAt"));
    }

    @Test
    void mapsInteractionRows() {
        SocialReactionRecord reaction = mapper.reaction(record(fields(
                "contentId", "content_a",
                "userId", "viewer_a",
                "reactionType", "like",
                "createdAt", NOW.toString())));
        SocialCommentRecord comment = mapper.comment(record(fields(
                "commentId", "comment_a",
                "contentId", "content_a",
                "authorId", "author_a",
                "text", "nice",
                "parentCommentId", "parent_a",
                "createdAt", NOW.toString())));
        SocialContentTagRecord tag = mapper.contentTag(record(fields(
                "contentId", "content_a",
                "tag", "city",
                "createdAt", NOW.toString())));
        SocialTagFollowRecord tagFollow = mapper.tagFollow(record(fields(
                "userId", "viewer_a",
                "tag", "city",
                "createdAt", NOW.toString())));
        SocialCommentReactionRecord commentReaction = mapper.commentReaction(record(fields(
                "commentId", "comment_a",
                "userId", "viewer_a",
                "reactionType", "like",
                "createdAt", NOW.toString())));
        SocialSaveRecord save = mapper.save(record(fields(
                "contentId", "content_a",
                "userId", "viewer_a",
                "createdAt", NOW.toString())));
        SocialShareRecord share = mapper.share(record(fields(
                "shareId", "share_a",
                "contentId", "content_a",
                "userId", "viewer_a",
                "message", "look",
                "createdAt", NOW.toString())));
        SocialContentHideRecord hide = mapper.contentHide(record(fields(
                "contentId", "content_a",
                "userId", "viewer_a",
                "reason", "not now",
                "createdAt", NOW.toString())));

        assertEquals("like", reaction.reactionType());
        assertEquals("parent_a", comment.parentCommentId());
        assertEquals("city", tag.tag());
        assertEquals("viewer_a", tagFollow.userId());
        assertEquals("like", commentReaction.reactionType());
        assertEquals("viewer_a", save.userId());
        assertEquals("look", share.message());
        assertEquals("not now", hide.reason());
    }

    @Test
    void mapsReportAndMentionRows() {
        SocialContentReportRecord report = mapper.contentReport(record(fields(
                "reportId", "report_a",
                "contentId", "content_a",
                "reporterId", "viewer_a",
                "reason", "spam",
                "detail", "detail",
                "status", "open",
                "createdAt", NOW.toString(),
                "updatedAt", UPDATED_AT.toString())));
        SocialMentionRecord mention = mapper.mention(record(fields(
                "mentionId", "mention_a",
                "contentId", "content_a",
                "commentId", "comment_a",
                "actorId", "author_a",
                "mentionedUserId", "viewer_a",
                "sourceType", "comment",
                "createdAt", NOW.toString())));

        assertEquals("open", report.status());
        assertEquals(UPDATED_AT, report.updatedAt());
        assertEquals("viewer_a", mention.mentionedUserId());
        assertEquals("comment", mention.sourceType());
    }

    private Map<String, Object> contentFields() {
        return fields(
                "contentId", "content_a",
                "ownerId", "owner_a",
                "contentType", "post",
                "scope", "friends",
                "targetId", "group_a",
                "caption", "caption",
                "createdAt", NOW.toString());
    }

    private Map<String, Object> fields(Object... pairs) {
        Map<String, Object> fields = new LinkedHashMap<>();
        for (int index = 0; index < pairs.length; index += 2) {
            fields.put((String) pairs[index], pairs[index + 1]);
        }
        return fields;
    }

    private Record record(Map<String, Object> fields) {
        List<String> keys = new ArrayList<>(fields.keySet());
        List<Value> values = fields.values().stream()
                .map(Values::value)
                .toList();
        return new InternalRecord(keys, values);
    }
}
