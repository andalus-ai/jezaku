package tech.kayys.jezaku.social;

import java.util.List;

/**
 * Persists social content, engagement, tagging, moderation report, and mention graph records.
 */
interface SocialContentGraphStore {
    SocialContentRecord content(String contentId);

    List<SocialContentRecord> contents();

    void saveContent(SocialContentRecord content);

    void removeContent(String contentId);

    SocialReactionRecord reaction(String contentId, String userId);

    List<SocialReactionRecord> reactions(String contentId);

    void saveReaction(SocialReactionRecord reaction);

    void removeReaction(String contentId, String userId);

    List<SocialContentTagRecord> tags();

    List<SocialContentTagRecord> contentTags(String contentId);

    List<SocialContentTagRecord> taggedContent(String tag);

    void saveContentTag(SocialContentTagRecord tag);

    void removeContentTags(String contentId);

    SocialTagFollowRecord tagFollow(String userId, String tag);

    List<SocialTagFollowRecord> tagFollows();

    List<SocialTagFollowRecord> tagFollows(String tag);

    List<SocialTagFollowRecord> tagFollowsByUser(String userId);

    void saveTagFollow(SocialTagFollowRecord follow);

    void removeTagFollow(String userId, String tag);

    SocialCommentRecord comment(String commentId);

    List<SocialCommentRecord> comments(String contentId);

    void saveComment(SocialCommentRecord comment);

    void removeComment(String commentId);

    SocialCommentReactionRecord commentReaction(String commentId, String userId);

    List<SocialCommentReactionRecord> commentReactions(String commentId);

    void saveCommentReaction(SocialCommentReactionRecord reaction);

    void removeCommentReaction(String commentId, String userId);

    SocialSaveRecord save(String contentId, String userId);

    List<SocialSaveRecord> saves(String contentId);

    List<SocialSaveRecord> savedByUser(String userId);

    void saveSave(SocialSaveRecord save);

    void removeSave(String contentId, String userId);

    SocialShareRecord share(String shareId);

    List<SocialShareRecord> shares(String contentId);

    void saveShare(SocialShareRecord share);

    void removeShare(String shareId);

    SocialContentHideRecord contentHide(String contentId, String userId);

    List<SocialContentHideRecord> contentHides(String contentId);

    List<SocialContentHideRecord> hiddenByUser(String userId);

    void saveContentHide(SocialContentHideRecord hide);

    void removeContentHide(String contentId, String userId);

    SocialContentReportRecord contentReport(String reportId);

    List<SocialContentReportRecord> contentReports();

    void saveContentReport(SocialContentReportRecord report);

    void removeContentReports(String contentId);

    List<SocialMentionRecord> mentions(String contentId);

    List<SocialMentionRecord> mentionsForUser(String userId);

    void saveMention(SocialMentionRecord mention);

    void removeMentionsForContent(String contentId);

    void removeMentionsForContentSource(String contentId, String sourceType);

    void removeMentionsForComment(String commentId);
}
