package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;

/**
 * Routes social graph repository calls to the domain-specific graph stores.
 */
abstract class StoreBackedSocialGraphRepository implements SocialGraphRepository {
    private final SocialRelationshipGraphStore relationships;
    private final SocialCircleGraphStore circles;
    private final SocialContentGraphStore contentStore;
    private final SocialActivityGraphStore activityStore;
    private final SocialMonetizationGraphStore monetizationStore;

    StoreBackedSocialGraphRepository(
            SocialRelationshipGraphStore relationships,
            SocialCircleGraphStore circles,
            SocialContentGraphStore contentStore,
            SocialActivityGraphStore activityStore,
            SocialMonetizationGraphStore monetizationStore) {
        this.relationships = relationships;
        this.circles = circles;
        this.contentStore = contentStore;
        this.activityStore = activityStore;
        this.monetizationStore = monetizationStore;
    }

    @Override
    public FriendRequestRecord friendRequest(String requestId) {
        return relationships.friendRequest(requestId);
    }

    @Override
    public List<FriendRequestRecord> friendRequests() {
        return relationships.friendRequests();
    }

    @Override
    public void saveFriendRequest(FriendRequestRecord request) {
        relationships.saveFriendRequest(request);
    }

    @Override
    public void removeFriendRequest(String requestId) {
        relationships.removeFriendRequest(requestId);
    }

    @Override
    public List<FriendshipRecord> friendships() {
        return relationships.friendships();
    }

    @Override
    public void saveFriendship(String firstUserId, String secondUserId, Instant createdAt) {
        relationships.saveFriendship(firstUserId, secondUserId, createdAt);
    }

    @Override
    public void removeFriendship(String firstUserId, String secondUserId) {
        relationships.removeFriendship(firstUserId, secondUserId);
    }

    @Override
    public List<CloseFriendRecord> closeFriends() {
        return relationships.closeFriends();
    }

    @Override
    public void saveCloseFriend(String ownerId, String friendId, Instant createdAt) {
        relationships.saveCloseFriend(ownerId, friendId, createdAt);
    }

    @Override
    public void removeCloseFriend(String ownerId, String friendId) {
        relationships.removeCloseFriend(ownerId, friendId);
    }

    @Override
    public SocialUserFollowRecord userFollow(String followerId, String followedUserId) {
        return relationships.userFollow(followerId, followedUserId);
    }

    @Override
    public List<SocialUserFollowRecord> userFollows() {
        return relationships.userFollows();
    }

    @Override
    public List<SocialUserFollowRecord> followers(String userId) {
        return relationships.followers(userId);
    }

    @Override
    public List<SocialUserFollowRecord> following(String userId) {
        return relationships.following(userId);
    }

    @Override
    public void saveUserFollow(SocialUserFollowRecord follow) {
        relationships.saveUserFollow(follow);
    }

    @Override
    public void removeUserFollow(String followerId, String followedUserId) {
        relationships.removeUserFollow(followerId, followedUserId);
    }

    @Override
    public SocialUserFollowRequestRecord userFollowRequest(String followerId, String followedUserId) {
        return relationships.userFollowRequest(followerId, followedUserId);
    }

    @Override
    public List<SocialUserFollowRequestRecord> userFollowRequests() {
        return relationships.userFollowRequests();
    }

    @Override
    public void saveUserFollowRequest(SocialUserFollowRequestRecord request) {
        relationships.saveUserFollowRequest(request);
    }

    @Override
    public void removeUserFollowRequest(String followerId, String followedUserId) {
        relationships.removeUserFollowRequest(followerId, followedUserId);
    }

    @Override
    public SocialUserProfileRecord userProfile(String userId) {
        return relationships.userProfile(userId);
    }

    @Override
    public SocialUserProfileRecord userProfileByHandle(String handle) {
        return relationships.userProfileByHandle(handle);
    }

    @Override
    public List<SocialUserProfileRecord> userProfiles() {
        return relationships.userProfiles();
    }

    @Override
    public void saveUserProfile(SocialUserProfileRecord profile) {
        relationships.saveUserProfile(profile);
    }

    @Override
    public List<BlockRecord> blocks() {
        return relationships.blocks();
    }

    @Override
    public void saveBlock(BlockRecord block) {
        relationships.saveBlock(block);
    }

    @Override
    public void removeBlock(String userId, String blockedUserId) {
        relationships.removeBlock(userId, blockedUserId);
    }

    @Override
    public SocialMuteRecord mute(String userId, String targetType, String targetId) {
        return relationships.mute(userId, targetType, targetId);
    }

    @Override
    public List<SocialMuteRecord> mutes() {
        return relationships.mutes();
    }

    @Override
    public List<SocialMuteRecord> mutesByUser(String userId) {
        return relationships.mutesByUser(userId);
    }

    @Override
    public void saveMute(SocialMuteRecord mute) {
        relationships.saveMute(mute);
    }

    @Override
    public void removeMute(String userId, String targetType, String targetId) {
        relationships.removeMute(userId, targetType, targetId);
    }

    @Override
    public List<FamilyLinkRecord> familyLinks() {
        return relationships.familyLinks();
    }

    @Override
    public void saveFamilyLink(FamilyLinkRecord link) {
        relationships.saveFamilyLink(link);
    }

    @Override
    public void removeFamilyLink(String firstUserId, String secondUserId) {
        relationships.removeFamilyLink(firstUserId, secondUserId);
    }

    @Override
    public SocialGroupRecord group(String groupId) {
        return circles.group(groupId);
    }

    @Override
    public List<SocialGroupRecord> groups() {
        return circles.groups();
    }

    @Override
    public void saveGroup(SocialGroupRecord group) {
        circles.saveGroup(group);
    }

    @Override
    public SocialCommunityRecord community(String communityId) {
        return circles.community(communityId);
    }

    @Override
    public List<SocialCommunityRecord> communities() {
        return circles.communities();
    }

    @Override
    public void saveCommunity(SocialCommunityRecord community) {
        circles.saveCommunity(community);
    }

    @Override
    public List<MembershipRecord> groupMemberships() {
        return circles.groupMemberships();
    }

    @Override
    public void saveGroupMembership(MembershipRecord membership) {
        circles.saveGroupMembership(membership);
    }

    @Override
    public void removeGroupMembership(String memberId, String groupId) {
        circles.removeGroupMembership(memberId, groupId);
    }

    @Override
    public List<MembershipRecord> communityMemberships() {
        return circles.communityMemberships();
    }

    @Override
    public void saveCommunityMembership(MembershipRecord membership) {
        circles.saveCommunityMembership(membership);
    }

    @Override
    public void removeCommunityMembership(String memberId, String communityId) {
        circles.removeCommunityMembership(memberId, communityId);
    }

    @Override
    public CircleMembershipRequestRecord circleMembershipRequest(String requestId) {
        return circles.circleMembershipRequest(requestId);
    }

    @Override
    public List<CircleMembershipRequestRecord> circleMembershipRequests() {
        return circles.circleMembershipRequests();
    }

    @Override
    public void saveCircleMembershipRequest(CircleMembershipRequestRecord request) {
        circles.saveCircleMembershipRequest(request);
    }

    @Override
    public void removeCircleMembershipRequest(String requestId) {
        circles.removeCircleMembershipRequest(requestId);
    }

    @Override
    public CircleContentModerationRecord circleContentModeration(String moderationId) {
        return circles.circleContentModeration(moderationId);
    }

    @Override
    public List<CircleContentModerationRecord> circleContentModerations() {
        return circles.circleContentModerations();
    }

    @Override
    public void saveCircleContentModeration(CircleContentModerationRecord moderation) {
        circles.saveCircleContentModeration(moderation);
    }

    @Override
    public void removeCircleContentModerations(String contentId) {
        circles.removeCircleContentModerations(contentId);
    }

    @Override
    public SocialContentRecord content(String contentId) {
        return contentStore.content(contentId);
    }

    @Override
    public List<SocialContentRecord> contents() {
        return contentStore.contents();
    }

    @Override
    public void saveContent(SocialContentRecord content) {
        contentStore.saveContent(content);
    }

    @Override
    public void removeContent(String contentId) {
        contentStore.removeContent(contentId);
    }

    @Override
    public SocialReactionRecord reaction(String contentId, String userId) {
        return contentStore.reaction(contentId, userId);
    }

    @Override
    public List<SocialReactionRecord> reactions(String contentId) {
        return contentStore.reactions(contentId);
    }

    @Override
    public void saveReaction(SocialReactionRecord reaction) {
        contentStore.saveReaction(reaction);
    }

    @Override
    public void removeReaction(String contentId, String userId) {
        contentStore.removeReaction(contentId, userId);
    }

    @Override
    public List<SocialContentTagRecord> tags() {
        return contentStore.tags();
    }

    @Override
    public List<SocialContentTagRecord> contentTags(String contentId) {
        return contentStore.contentTags(contentId);
    }

    @Override
    public List<SocialContentTagRecord> taggedContent(String tag) {
        return contentStore.taggedContent(tag);
    }

    @Override
    public void saveContentTag(SocialContentTagRecord tag) {
        contentStore.saveContentTag(tag);
    }

    @Override
    public void removeContentTags(String contentId) {
        contentStore.removeContentTags(contentId);
    }

    @Override
    public SocialTagFollowRecord tagFollow(String userId, String tag) {
        return contentStore.tagFollow(userId, tag);
    }

    @Override
    public List<SocialTagFollowRecord> tagFollows() {
        return contentStore.tagFollows();
    }

    @Override
    public List<SocialTagFollowRecord> tagFollows(String tag) {
        return contentStore.tagFollows(tag);
    }

    @Override
    public List<SocialTagFollowRecord> tagFollowsByUser(String userId) {
        return contentStore.tagFollowsByUser(userId);
    }

    @Override
    public void saveTagFollow(SocialTagFollowRecord follow) {
        contentStore.saveTagFollow(follow);
    }

    @Override
    public void removeTagFollow(String userId, String tag) {
        contentStore.removeTagFollow(userId, tag);
    }

    @Override
    public SocialCommentRecord comment(String commentId) {
        return contentStore.comment(commentId);
    }

    @Override
    public List<SocialCommentRecord> comments(String contentId) {
        return contentStore.comments(contentId);
    }

    @Override
    public void saveComment(SocialCommentRecord comment) {
        contentStore.saveComment(comment);
    }

    @Override
    public void removeComment(String commentId) {
        contentStore.removeComment(commentId);
    }

    @Override
    public SocialCommentReactionRecord commentReaction(String commentId, String userId) {
        return contentStore.commentReaction(commentId, userId);
    }

    @Override
    public List<SocialCommentReactionRecord> commentReactions(String commentId) {
        return contentStore.commentReactions(commentId);
    }

    @Override
    public void saveCommentReaction(SocialCommentReactionRecord reaction) {
        contentStore.saveCommentReaction(reaction);
    }

    @Override
    public void removeCommentReaction(String commentId, String userId) {
        contentStore.removeCommentReaction(commentId, userId);
    }

    @Override
    public SocialSaveRecord save(String contentId, String userId) {
        return contentStore.save(contentId, userId);
    }

    @Override
    public List<SocialSaveRecord> saves(String contentId) {
        return contentStore.saves(contentId);
    }

    @Override
    public List<SocialSaveRecord> savedByUser(String userId) {
        return contentStore.savedByUser(userId);
    }

    @Override
    public void saveSave(SocialSaveRecord save) {
        contentStore.saveSave(save);
    }

    @Override
    public void removeSave(String contentId, String userId) {
        contentStore.removeSave(contentId, userId);
    }

    @Override
    public SocialShareRecord share(String shareId) {
        return contentStore.share(shareId);
    }

    @Override
    public List<SocialShareRecord> shares(String contentId) {
        return contentStore.shares(contentId);
    }

    @Override
    public void saveShare(SocialShareRecord share) {
        contentStore.saveShare(share);
    }

    @Override
    public void removeShare(String shareId) {
        contentStore.removeShare(shareId);
    }

    @Override
    public SocialContentHideRecord contentHide(String contentId, String userId) {
        return contentStore.contentHide(contentId, userId);
    }

    @Override
    public List<SocialContentHideRecord> contentHides(String contentId) {
        return contentStore.contentHides(contentId);
    }

    @Override
    public List<SocialContentHideRecord> hiddenByUser(String userId) {
        return contentStore.hiddenByUser(userId);
    }

    @Override
    public void saveContentHide(SocialContentHideRecord hide) {
        contentStore.saveContentHide(hide);
    }

    @Override
    public void removeContentHide(String contentId, String userId) {
        contentStore.removeContentHide(contentId, userId);
    }

    @Override
    public SocialContentReportRecord contentReport(String reportId) {
        return contentStore.contentReport(reportId);
    }

    @Override
    public List<SocialContentReportRecord> contentReports() {
        return contentStore.contentReports();
    }

    @Override
    public void saveContentReport(SocialContentReportRecord report) {
        contentStore.saveContentReport(report);
    }

    @Override
    public void removeContentReports(String contentId) {
        contentStore.removeContentReports(contentId);
    }

    @Override
    public List<SocialMentionRecord> mentions(String contentId) {
        return contentStore.mentions(contentId);
    }

    @Override
    public List<SocialMentionRecord> mentionsForUser(String userId) {
        return contentStore.mentionsForUser(userId);
    }

    @Override
    public void saveMention(SocialMentionRecord mention) {
        contentStore.saveMention(mention);
    }

    @Override
    public void removeMentionsForContent(String contentId) {
        contentStore.removeMentionsForContent(contentId);
    }

    @Override
    public void removeMentionsForContentSource(String contentId, String sourceType) {
        contentStore.removeMentionsForContentSource(contentId, sourceType);
    }

    @Override
    public void removeMentionsForComment(String commentId) {
        contentStore.removeMentionsForComment(commentId);
    }

    @Override
    public SocialActivityRecord activity(String activityId) {
        return activityStore.activity(activityId);
    }

    @Override
    public List<SocialActivityRecord> activities() {
        return activityStore.activities();
    }

    @Override
    public void saveActivity(SocialActivityRecord activity) {
        activityStore.saveActivity(activity);
    }

    @Override
    public void removeActivitiesForContent(String contentId) {
        activityStore.removeActivitiesForContent(contentId);
    }

    @Override
    public SocialAdCampaignRecord adCampaign(String campaignId) {
        return monetizationStore.adCampaign(campaignId);
    }

    @Override
    public List<SocialAdCampaignRecord> adCampaigns() {
        return monetizationStore.adCampaigns();
    }

    @Override
    public void saveAdCampaign(SocialAdCampaignRecord campaign) {
        monetizationStore.saveAdCampaign(campaign);
    }

    @Override
    public SocialAdEventRecord adEvent(String eventId) {
        return monetizationStore.adEvent(eventId);
    }

    @Override
    public List<SocialAdEventRecord> adEvents() {
        return monetizationStore.adEvents();
    }

    @Override
    public void saveAdEvent(SocialAdEventRecord event) {
        monetizationStore.saveAdEvent(event);
    }
}
