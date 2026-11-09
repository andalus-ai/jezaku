package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Stores social content, engagement, tag, moderation report, and mention records in memory.
 */
final class InMemoryContentGraphStore implements SocialContentGraphStore {
    private final Map<String, SocialContentRecord> contents = new ConcurrentHashMap<>();
    private final Map<String, SocialReactionRecord> reactions = new ConcurrentHashMap<>();
    private final Map<String, SocialContentTagRecord> tags = new ConcurrentHashMap<>();
    private final Map<String, SocialTagFollowRecord> tagFollows = new ConcurrentHashMap<>();
    private final Map<String, SocialCommentRecord> comments = new ConcurrentHashMap<>();
    private final Map<String, SocialCommentReactionRecord> commentReactions = new ConcurrentHashMap<>();
    private final Map<String, SocialSaveRecord> saves = new ConcurrentHashMap<>();
    private final Map<String, SocialShareRecord> shares = new ConcurrentHashMap<>();
    private final Map<String, SocialContentHideRecord> contentHides = new ConcurrentHashMap<>();
    private final Map<String, SocialContentReportRecord> contentReports = new ConcurrentHashMap<>();
    private final Map<String, SocialMentionRecord> mentions = new ConcurrentHashMap<>();

    @Override
    public SocialContentRecord content(String contentId) {
        return contents.get(requireText(contentId, "contentId"));
    }

    @Override
    public List<SocialContentRecord> contents() {
        return List.copyOf(contents.values());
    }

    @Override
    public void saveContent(SocialContentRecord content) {
        contents.put(requireText(content.contentId(), "contentId"), content);
    }

    @Override
    public void removeContent(String contentId) {
        contents.remove(requireText(contentId, "contentId"));
    }

    @Override
    public SocialReactionRecord reaction(String contentId, String userId) {
        return reactions.get(contentUserKey(contentId, userId));
    }

    @Override
    public List<SocialReactionRecord> reactions(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return reactions.values().stream()
                .filter(reaction -> reaction.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public void saveReaction(SocialReactionRecord reaction) {
        reactions.put(contentUserKey(reaction.contentId(), reaction.userId()), reaction);
    }

    @Override
    public void removeReaction(String contentId, String userId) {
        reactions.remove(contentUserKey(contentId, userId));
    }

    @Override
    public List<SocialContentTagRecord> tags() {
        return List.copyOf(tags.values());
    }

    @Override
    public List<SocialContentTagRecord> contentTags(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return tags.values().stream()
                .filter(tag -> tag.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public List<SocialContentTagRecord> taggedContent(String tag) {
        String normalizedTag = requireText(tag, "tag");
        return tags.values().stream()
                .filter(contentTag -> contentTag.tag().equals(normalizedTag))
                .toList();
    }

    @Override
    public void saveContentTag(SocialContentTagRecord tag) {
        tags.put(contentTagKey(tag.contentId(), tag.tag()), tag);
    }

    @Override
    public void removeContentTags(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        tags.values().removeIf(tag -> tag.contentId().equals(normalizedContentId));
    }

    @Override
    public SocialTagFollowRecord tagFollow(String userId, String tag) {
        return tagFollows.get(userTagKey(userId, tag));
    }

    @Override
    public List<SocialTagFollowRecord> tagFollows() {
        return List.copyOf(tagFollows.values());
    }

    @Override
    public List<SocialTagFollowRecord> tagFollows(String tag) {
        String normalizedTag = requireText(tag, "tag");
        return tagFollows.values().stream()
                .filter(follow -> follow.tag().equals(normalizedTag))
                .toList();
    }

    @Override
    public List<SocialTagFollowRecord> tagFollowsByUser(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return tagFollows.values().stream()
                .filter(follow -> follow.userId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public void saveTagFollow(SocialTagFollowRecord follow) {
        tagFollows.put(userTagKey(follow.userId(), follow.tag()), follow);
    }

    @Override
    public void removeTagFollow(String userId, String tag) {
        tagFollows.remove(userTagKey(userId, tag));
    }

    @Override
    public SocialCommentRecord comment(String commentId) {
        return comments.get(requireText(commentId, "commentId"));
    }

    @Override
    public List<SocialCommentRecord> comments(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return comments.values().stream()
                .filter(comment -> comment.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public void saveComment(SocialCommentRecord comment) {
        comments.put(requireText(comment.commentId(), "commentId"), comment);
    }

    @Override
    public void removeComment(String commentId) {
        comments.remove(requireText(commentId, "commentId"));
    }

    @Override
    public SocialCommentReactionRecord commentReaction(String commentId, String userId) {
        return commentReactions.get(commentUserKey(commentId, userId));
    }

    @Override
    public List<SocialCommentReactionRecord> commentReactions(String commentId) {
        String normalizedCommentId = requireText(commentId, "commentId");
        return commentReactions.values().stream()
                .filter(reaction -> reaction.commentId().equals(normalizedCommentId))
                .toList();
    }

    @Override
    public void saveCommentReaction(SocialCommentReactionRecord reaction) {
        commentReactions.put(commentUserKey(reaction.commentId(), reaction.userId()), reaction);
    }

    @Override
    public void removeCommentReaction(String commentId, String userId) {
        commentReactions.remove(commentUserKey(commentId, userId));
    }

    @Override
    public SocialSaveRecord save(String contentId, String userId) {
        return saves.get(contentUserKey(contentId, userId));
    }

    @Override
    public List<SocialSaveRecord> saves(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return saves.values().stream()
                .filter(save -> save.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public List<SocialSaveRecord> savedByUser(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return saves.values().stream()
                .filter(save -> save.userId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public void saveSave(SocialSaveRecord save) {
        saves.put(contentUserKey(save.contentId(), save.userId()), save);
    }

    @Override
    public void removeSave(String contentId, String userId) {
        saves.remove(contentUserKey(contentId, userId));
    }

    @Override
    public SocialShareRecord share(String shareId) {
        return shares.get(requireText(shareId, "shareId"));
    }

    @Override
    public List<SocialShareRecord> shares(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return shares.values().stream()
                .filter(share -> share.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public void saveShare(SocialShareRecord share) {
        shares.put(requireText(share.shareId(), "shareId"), share);
    }

    @Override
    public void removeShare(String shareId) {
        shares.remove(requireText(shareId, "shareId"));
    }

    @Override
    public SocialContentHideRecord contentHide(String contentId, String userId) {
        return contentHides.get(contentUserKey(contentId, userId));
    }

    @Override
    public List<SocialContentHideRecord> contentHides(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return contentHides.values().stream()
                .filter(hide -> hide.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public List<SocialContentHideRecord> hiddenByUser(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return contentHides.values().stream()
                .filter(hide -> hide.userId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public void saveContentHide(SocialContentHideRecord hide) {
        contentHides.put(contentUserKey(hide.contentId(), hide.userId()), hide);
    }

    @Override
    public void removeContentHide(String contentId, String userId) {
        contentHides.remove(contentUserKey(contentId, userId));
    }

    @Override
    public SocialContentReportRecord contentReport(String reportId) {
        return contentReports.get(requireText(reportId, "reportId"));
    }

    @Override
    public List<SocialContentReportRecord> contentReports() {
        return List.copyOf(contentReports.values());
    }

    @Override
    public void saveContentReport(SocialContentReportRecord report) {
        contentReports.put(requireText(report.reportId(), "reportId"), report);
    }

    @Override
    public void removeContentReports(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        contentReports.values().removeIf(report -> report.contentId().equals(normalizedContentId));
    }

    @Override
    public List<SocialMentionRecord> mentions(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        return mentions.values().stream()
                .filter(mention -> mention.contentId().equals(normalizedContentId))
                .toList();
    }

    @Override
    public List<SocialMentionRecord> mentionsForUser(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return mentions.values().stream()
                .filter(mention -> mention.mentionedUserId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public void saveMention(SocialMentionRecord mention) {
        mentions.put(requireText(mention.mentionId(), "mentionId"), mention);
    }

    @Override
    public void removeMentionsForContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        mentions.values().removeIf(mention -> mention.contentId().equals(normalizedContentId));
    }

    @Override
    public void removeMentionsForContentSource(String contentId, String sourceType) {
        String normalizedContentId = requireText(contentId, "contentId");
        String normalizedSourceType = requireText(sourceType, "sourceType");
        mentions.values().removeIf(mention -> mention.contentId().equals(normalizedContentId)
                && mention.sourceType().equals(normalizedSourceType));
    }

    @Override
    public void removeMentionsForComment(String commentId) {
        String normalizedCommentId = requireText(commentId, "commentId");
        mentions.values().removeIf(mention -> mention.commentId().equals(normalizedCommentId));
    }

    void clear() {
        contents.clear();
        reactions.clear();
        tags.clear();
        tagFollows.clear();
        comments.clear();
        commentReactions.clear();
        saves.clear();
        shares.clear();
        contentHides.clear();
        contentReports.clear();
        mentions.clear();
    }

    private String contentUserKey(String contentId, String userId) {
        return requireText(contentId, "contentId") + "->" + requireText(userId, "userId");
    }

    private String contentTagKey(String contentId, String tag) {
        return requireText(contentId, "contentId") + "#" + requireText(tag, "tag");
    }

    private String userTagKey(String userId, String tag) {
        return requireText(userId, "userId") + "#" + requireText(tag, "tag");
    }

    private String commentUserKey(String commentId, String userId) {
        return requireText(commentId, "commentId") + "->" + requireText(userId, "userId");
    }
}
