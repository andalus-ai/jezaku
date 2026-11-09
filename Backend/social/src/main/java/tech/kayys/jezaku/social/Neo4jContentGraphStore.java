package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jContentCypher.DELETE_CONTENT;
import static tech.kayys.jezaku.social.Neo4jContentCypher.READ_CONTENT;
import static tech.kayys.jezaku.social.Neo4jContentCypher.READ_CONTENTS;
import static tech.kayys.jezaku.social.Neo4jContentCypher.SAVE_CONTENT;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.DELETE_CONTENT_HIDE;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.DELETE_CONTENT_REPORTS;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.READ_CONTENT_HIDE;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.READ_CONTENT_HIDES;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.READ_CONTENT_REPORT;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.READ_CONTENT_REPORTS;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.READ_HIDDEN_BY_USER;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.SAVE_CONTENT_HIDE;
import static tech.kayys.jezaku.social.Neo4jContentSafetyCypher.SAVE_CONTENT_REPORT;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.DELETE_COMMENT;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.DELETE_COMMENT_REACTION;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.DELETE_REACTION;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.DELETE_SAVE;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.DELETE_SHARE;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_COMMENT;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_COMMENT_REACTION;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_COMMENT_REACTIONS;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_COMMENTS;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_REACTION;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_REACTIONS;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_SAVE;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_SAVED_BY_USER;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_SAVES;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_SHARE;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.READ_SHARES;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.SAVE_COMMENT;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.SAVE_COMMENT_REACTION;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.SAVE_REACTION;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.SAVE_SAVE;
import static tech.kayys.jezaku.social.Neo4jEngagementCypher.SAVE_SHARE;
import static tech.kayys.jezaku.social.Neo4jMentionCypher.DELETE_MENTIONS_FOR_COMMENT;
import static tech.kayys.jezaku.social.Neo4jMentionCypher.DELETE_MENTIONS_FOR_CONTENT;
import static tech.kayys.jezaku.social.Neo4jMentionCypher.DELETE_MENTIONS_FOR_CONTENT_SOURCE;
import static tech.kayys.jezaku.social.Neo4jMentionCypher.READ_MENTIONS;
import static tech.kayys.jezaku.social.Neo4jMentionCypher.READ_MENTIONS_FOR_USER;
import static tech.kayys.jezaku.social.Neo4jMentionCypher.SAVE_MENTION;
import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;
import static tech.kayys.jezaku.social.Neo4jTagCypher.DELETE_CONTENT_TAGS;
import static tech.kayys.jezaku.social.Neo4jTagCypher.DELETE_TAG_FOLLOW;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_ALL_TAG_FOLLOWS;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_CONTENT_TAGS;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_TAGGED_CONTENT;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_TAGS;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_TAG_FOLLOW;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_TAG_FOLLOWS;
import static tech.kayys.jezaku.social.Neo4jTagCypher.READ_TAG_FOLLOWS_BY_USER;
import static tech.kayys.jezaku.social.Neo4jTagCypher.SAVE_CONTENT_TAG;
import static tech.kayys.jezaku.social.Neo4jTagCypher.SAVE_TAG_FOLLOW;
import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Persists Neo4j content, engagement, tag, safety, and mention graph records.
 */
final class Neo4jContentGraphStore extends Neo4jGraphStoreSupport implements SocialContentGraphStore {
    private final Neo4jContentRecordMapper mapper = new Neo4jContentRecordMapper();

    Neo4jContentGraphStore(Neo4jSocialGraphClient client) {
        super(client);
    }

    @Override
    public SocialContentRecord content(String contentId) {
        return readOne(READ_CONTENT, Map.of("contentId", requireText(contentId, "contentId")), mapper::content);
    }

    @Override
    public List<SocialContentRecord> contents() {
        return readList(READ_CONTENTS, Map.of(), mapper::content);
    }

    @Override
    public void saveContent(SocialContentRecord content) {
        write(SAVE_CONTENT, mapper.contentParameters(content));
    }

    @Override
    public void removeContent(String contentId) {
        write(DELETE_CONTENT, Map.of("contentId", requireText(contentId, "contentId")));
    }

    @Override
    public SocialReactionRecord reaction(String contentId, String userId) {
        return readOne(READ_REACTION, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "userId", requireText(userId, "userId")), mapper::reaction);
    }

    @Override
    public List<SocialReactionRecord> reactions(String contentId) {
        return readList(READ_REACTIONS, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::reaction);
    }

    @Override
    public void saveReaction(SocialReactionRecord reaction) {
        write(SAVE_REACTION, Map.of(
                "contentId", reaction.contentId(),
                "userId", reaction.userId(),
                "reactionType", reaction.reactionType(),
                "createdAt", iso(reaction.createdAt())));
    }

    @Override
    public void removeReaction(String contentId, String userId) {
        write(DELETE_REACTION, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "userId", requireText(userId, "userId")));
    }

    @Override
    public List<SocialContentTagRecord> tags() {
        return readList(READ_TAGS, Map.of(), mapper::contentTag);
    }

    @Override
    public List<SocialContentTagRecord> contentTags(String contentId) {
        return readList(READ_CONTENT_TAGS, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::contentTag);
    }

    @Override
    public List<SocialContentTagRecord> taggedContent(String tag) {
        return readList(READ_TAGGED_CONTENT, Map.of("tag", requireText(tag, "tag")),
                mapper::contentTag);
    }

    @Override
    public void saveContentTag(SocialContentTagRecord tag) {
        write(SAVE_CONTENT_TAG, Map.of(
                "contentId", tag.contentId(),
                "tag", tag.tag(),
                "createdAt", iso(tag.createdAt())));
    }

    @Override
    public void removeContentTags(String contentId) {
        write(DELETE_CONTENT_TAGS, Map.of("contentId", requireText(contentId, "contentId")));
    }

    @Override
    public SocialTagFollowRecord tagFollow(String userId, String tag) {
        return readOne(READ_TAG_FOLLOW, Map.of(
                "userId", requireText(userId, "userId"),
                "tag", requireText(tag, "tag")), mapper::tagFollow);
    }

    @Override
    public List<SocialTagFollowRecord> tagFollows() {
        return readList(READ_ALL_TAG_FOLLOWS, Map.of(), mapper::tagFollow);
    }

    @Override
    public List<SocialTagFollowRecord> tagFollows(String tag) {
        return readList(READ_TAG_FOLLOWS, Map.of("tag", requireText(tag, "tag")),
                mapper::tagFollow);
    }

    @Override
    public List<SocialTagFollowRecord> tagFollowsByUser(String userId) {
        return readList(READ_TAG_FOLLOWS_BY_USER, Map.of("userId", requireText(userId, "userId")),
                mapper::tagFollow);
    }

    @Override
    public void saveTagFollow(SocialTagFollowRecord follow) {
        write(SAVE_TAG_FOLLOW, Map.of(
                "userId", follow.userId(),
                "tag", follow.tag(),
                "createdAt", iso(follow.createdAt())));
    }

    @Override
    public void removeTagFollow(String userId, String tag) {
        write(DELETE_TAG_FOLLOW, Map.of(
                "userId", requireText(userId, "userId"),
                "tag", requireText(tag, "tag")));
    }

    @Override
    public SocialCommentRecord comment(String commentId) {
        return readOne(READ_COMMENT, Map.of("commentId", requireText(commentId, "commentId")),
                mapper::comment);
    }

    @Override
    public List<SocialCommentRecord> comments(String contentId) {
        return readList(READ_COMMENTS, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::comment);
    }

    @Override
    public void saveComment(SocialCommentRecord comment) {
        write(SAVE_COMMENT, Map.of(
                "commentId", comment.commentId(),
                "contentId", comment.contentId(),
                "authorId", comment.authorId(),
                "text", comment.text(),
                "parentCommentId", comment.parentCommentId(),
                "createdAt", iso(comment.createdAt())));
    }

    @Override
    public void removeComment(String commentId) {
        write(DELETE_COMMENT, Map.of("commentId", requireText(commentId, "commentId")));
    }

    @Override
    public SocialCommentReactionRecord commentReaction(String commentId, String userId) {
        return readOne(READ_COMMENT_REACTION, Map.of(
                "commentId", requireText(commentId, "commentId"),
                "userId", requireText(userId, "userId")), mapper::commentReaction);
    }

    @Override
    public List<SocialCommentReactionRecord> commentReactions(String commentId) {
        return readList(READ_COMMENT_REACTIONS, Map.of("commentId", requireText(commentId, "commentId")),
                mapper::commentReaction);
    }

    @Override
    public void saveCommentReaction(SocialCommentReactionRecord reaction) {
        write(SAVE_COMMENT_REACTION, Map.of(
                "commentId", reaction.commentId(),
                "userId", reaction.userId(),
                "reactionType", reaction.reactionType(),
                "createdAt", iso(reaction.createdAt())));
    }

    @Override
    public void removeCommentReaction(String commentId, String userId) {
        write(DELETE_COMMENT_REACTION, Map.of(
                "commentId", requireText(commentId, "commentId"),
                "userId", requireText(userId, "userId")));
    }

    @Override
    public SocialSaveRecord save(String contentId, String userId) {
        return readOne(READ_SAVE, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "userId", requireText(userId, "userId")), mapper::save);
    }

    @Override
    public List<SocialSaveRecord> saves(String contentId) {
        return readList(READ_SAVES, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::save);
    }

    @Override
    public List<SocialSaveRecord> savedByUser(String userId) {
        return readList(READ_SAVED_BY_USER, Map.of("userId", requireText(userId, "userId")),
                mapper::save);
    }

    @Override
    public void saveSave(SocialSaveRecord save) {
        write(SAVE_SAVE, Map.of(
                "contentId", save.contentId(),
                "userId", save.userId(),
                "createdAt", iso(save.createdAt())));
    }

    @Override
    public void removeSave(String contentId, String userId) {
        write(DELETE_SAVE, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "userId", requireText(userId, "userId")));
    }

    @Override
    public SocialShareRecord share(String shareId) {
        return readOne(READ_SHARE, Map.of("shareId", requireText(shareId, "shareId")),
                mapper::share);
    }

    @Override
    public List<SocialShareRecord> shares(String contentId) {
        return readList(READ_SHARES, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::share);
    }

    @Override
    public void saveShare(SocialShareRecord share) {
        write(SAVE_SHARE, Map.of(
                "shareId", share.shareId(),
                "contentId", share.contentId(),
                "userId", share.userId(),
                "message", share.message(),
                "createdAt", iso(share.createdAt())));
    }

    @Override
    public void removeShare(String shareId) {
        write(DELETE_SHARE, Map.of("shareId", requireText(shareId, "shareId")));
    }

    @Override
    public SocialContentHideRecord contentHide(String contentId, String userId) {
        return readOne(READ_CONTENT_HIDE, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "userId", requireText(userId, "userId")), mapper::contentHide);
    }

    @Override
    public List<SocialContentHideRecord> contentHides(String contentId) {
        return readList(READ_CONTENT_HIDES, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::contentHide);
    }

    @Override
    public List<SocialContentHideRecord> hiddenByUser(String userId) {
        return readList(READ_HIDDEN_BY_USER, Map.of("userId", requireText(userId, "userId")),
                mapper::contentHide);
    }

    @Override
    public void saveContentHide(SocialContentHideRecord hide) {
        write(SAVE_CONTENT_HIDE, Map.of(
                "contentId", hide.contentId(),
                "userId", hide.userId(),
                "reason", hide.reason(),
                "createdAt", iso(hide.createdAt())));
    }

    @Override
    public void removeContentHide(String contentId, String userId) {
        write(DELETE_CONTENT_HIDE, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "userId", requireText(userId, "userId")));
    }

    @Override
    public SocialContentReportRecord contentReport(String reportId) {
        return readOne(READ_CONTENT_REPORT, Map.of("reportId", requireText(reportId, "reportId")),
                mapper::contentReport);
    }

    @Override
    public List<SocialContentReportRecord> contentReports() {
        return readList(READ_CONTENT_REPORTS, Map.of(), mapper::contentReport);
    }

    @Override
    public void saveContentReport(SocialContentReportRecord report) {
        write(SAVE_CONTENT_REPORT, Map.of(
                "reportId", report.reportId(),
                "contentId", report.contentId(),
                "reporterId", report.reporterId(),
                "reason", report.reason(),
                "detail", report.detail(),
                "status", report.status(),
                "createdAt", iso(report.createdAt()),
                "updatedAt", iso(report.updatedAt())));
    }

    @Override
    public void removeContentReports(String contentId) {
        write(DELETE_CONTENT_REPORTS, Map.of("contentId", requireText(contentId, "contentId")));
    }

    @Override
    public List<SocialMentionRecord> mentions(String contentId) {
        return readList(READ_MENTIONS, Map.of("contentId", requireText(contentId, "contentId")),
                mapper::mention);
    }

    @Override
    public List<SocialMentionRecord> mentionsForUser(String userId) {
        return readList(READ_MENTIONS_FOR_USER, Map.of("userId", requireText(userId, "userId")),
                mapper::mention);
    }

    @Override
    public void saveMention(SocialMentionRecord mention) {
        write(SAVE_MENTION, Map.of(
                "mentionId", mention.mentionId(),
                "contentId", mention.contentId(),
                "commentId", mention.commentId(),
                "actorId", mention.actorId(),
                "mentionedUserId", mention.mentionedUserId(),
                "sourceType", mention.sourceType(),
                "createdAt", iso(mention.createdAt())));
    }

    @Override
    public void removeMentionsForContent(String contentId) {
        write(DELETE_MENTIONS_FOR_CONTENT, Map.of("contentId", requireText(contentId, "contentId")));
    }

    @Override
    public void removeMentionsForContentSource(String contentId, String sourceType) {
        write(DELETE_MENTIONS_FOR_CONTENT_SOURCE, Map.of(
                "contentId", requireText(contentId, "contentId"),
                "sourceType", requireText(sourceType, "sourceType")));
    }

    @Override
    public void removeMentionsForComment(String commentId) {
        write(DELETE_MENTIONS_FOR_COMMENT, Map.of("commentId", requireText(commentId, "commentId")));
    }
}
