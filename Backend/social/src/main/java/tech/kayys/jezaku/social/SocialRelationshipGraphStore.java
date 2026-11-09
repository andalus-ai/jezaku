package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;

/**
 * Persists social relationship, profile, block, mute, and family graph records.
 */
interface SocialRelationshipGraphStore {
    FriendRequestRecord friendRequest(String requestId);

    List<FriendRequestRecord> friendRequests();

    void saveFriendRequest(FriendRequestRecord request);

    void removeFriendRequest(String requestId);

    List<FriendshipRecord> friendships();

    void saveFriendship(String firstUserId, String secondUserId, Instant createdAt);

    void removeFriendship(String firstUserId, String secondUserId);

    List<CloseFriendRecord> closeFriends();

    void saveCloseFriend(String ownerId, String friendId, Instant createdAt);

    void removeCloseFriend(String ownerId, String friendId);

    SocialUserFollowRecord userFollow(String followerId, String followedUserId);

    List<SocialUserFollowRecord> userFollows();

    List<SocialUserFollowRecord> followers(String userId);

    List<SocialUserFollowRecord> following(String userId);

    void saveUserFollow(SocialUserFollowRecord follow);

    void removeUserFollow(String followerId, String followedUserId);

    SocialUserFollowRequestRecord userFollowRequest(String followerId, String followedUserId);

    List<SocialUserFollowRequestRecord> userFollowRequests();

    void saveUserFollowRequest(SocialUserFollowRequestRecord request);

    void removeUserFollowRequest(String followerId, String followedUserId);

    SocialUserProfileRecord userProfile(String userId);

    SocialUserProfileRecord userProfileByHandle(String handle);

    List<SocialUserProfileRecord> userProfiles();

    void saveUserProfile(SocialUserProfileRecord profile);

    List<BlockRecord> blocks();

    void saveBlock(BlockRecord block);

    void removeBlock(String userId, String blockedUserId);

    SocialMuteRecord mute(String userId, String targetType, String targetId);

    List<SocialMuteRecord> mutes();

    List<SocialMuteRecord> mutesByUser(String userId);

    void saveMute(SocialMuteRecord mute);

    void removeMute(String userId, String targetType, String targetId);

    List<FamilyLinkRecord> familyLinks();

    void saveFamilyLink(FamilyLinkRecord link);

    void removeFamilyLink(String firstUserId, String secondUserId);
}
