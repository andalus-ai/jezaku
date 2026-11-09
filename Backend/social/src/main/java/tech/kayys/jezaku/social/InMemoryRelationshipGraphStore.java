package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Stores social relationship, profile, block, mute, and family records in memory.
 */
final class InMemoryRelationshipGraphStore implements SocialRelationshipGraphStore {
    private final Map<String, FriendRequestRecord> friendRequests = new ConcurrentHashMap<>();
    private final Map<String, FriendshipRecord> friendships = new ConcurrentHashMap<>();
    private final Map<String, CloseFriendRecord> closeFriends = new ConcurrentHashMap<>();
    private final Map<String, SocialUserFollowRecord> userFollows = new ConcurrentHashMap<>();
    private final Map<String, SocialUserFollowRequestRecord> userFollowRequests = new ConcurrentHashMap<>();
    private final Map<String, SocialUserProfileRecord> userProfiles = new ConcurrentHashMap<>();
    private final Map<String, BlockRecord> blocks = new ConcurrentHashMap<>();
    private final Map<String, SocialMuteRecord> mutes = new ConcurrentHashMap<>();
    private final Map<String, FamilyLinkRecord> familyLinks = new ConcurrentHashMap<>();

    @Override
    public FriendRequestRecord friendRequest(String requestId) {
        return friendRequests.get(requireText(requestId, "requestId"));
    }

    @Override
    public List<FriendRequestRecord> friendRequests() {
        return List.copyOf(friendRequests.values());
    }

    @Override
    public void saveFriendRequest(FriendRequestRecord request) {
        friendRequests.put(request.id(), request);
    }

    @Override
    public void removeFriendRequest(String requestId) {
        friendRequests.remove(requireText(requestId, "requestId"));
    }

    @Override
    public List<FriendshipRecord> friendships() {
        return List.copyOf(friendships.values());
    }

    @Override
    public void saveFriendship(String firstUserId, String secondUserId, Instant createdAt) {
        String first = requireText(firstUserId, "firstUserId");
        String second = requireText(secondUserId, "secondUserId");
        friendships.put(friendshipKey(first, second), new FriendshipRecord(first, second, createdAt));
    }

    @Override
    public void removeFriendship(String firstUserId, String secondUserId) {
        friendships.remove(friendshipKey(firstUserId, secondUserId));
    }

    @Override
    public List<CloseFriendRecord> closeFriends() {
        return List.copyOf(closeFriends.values());
    }

    @Override
    public void saveCloseFriend(String ownerId, String friendId, Instant createdAt) {
        String owner = requireText(ownerId, "ownerId");
        String friend = requireText(friendId, "friendId");
        closeFriends.put(directedKey(owner, friend), new CloseFriendRecord(owner, friend, createdAt));
    }

    @Override
    public void removeCloseFriend(String ownerId, String friendId) {
        closeFriends.remove(directedKey(ownerId, friendId));
    }

    @Override
    public SocialUserFollowRecord userFollow(String followerId, String followedUserId) {
        return userFollows.get(directedKey(followerId, followedUserId));
    }

    @Override
    public List<SocialUserFollowRecord> userFollows() {
        return List.copyOf(userFollows.values());
    }

    @Override
    public List<SocialUserFollowRecord> followers(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return userFollows.values().stream()
                .filter(follow -> follow.followedUserId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public List<SocialUserFollowRecord> following(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return userFollows.values().stream()
                .filter(follow -> follow.followerId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public void saveUserFollow(SocialUserFollowRecord follow) {
        userFollows.put(directedKey(follow.followerId(), follow.followedUserId()), follow);
    }

    @Override
    public void removeUserFollow(String followerId, String followedUserId) {
        userFollows.remove(directedKey(followerId, followedUserId));
    }

    @Override
    public SocialUserFollowRequestRecord userFollowRequest(String followerId, String followedUserId) {
        return userFollowRequests.get(directedKey(followerId, followedUserId));
    }

    @Override
    public List<SocialUserFollowRequestRecord> userFollowRequests() {
        return List.copyOf(userFollowRequests.values());
    }

    @Override
    public void saveUserFollowRequest(SocialUserFollowRequestRecord request) {
        userFollowRequests.put(directedKey(request.followerId(), request.followedUserId()), request);
    }

    @Override
    public void removeUserFollowRequest(String followerId, String followedUserId) {
        userFollowRequests.remove(directedKey(followerId, followedUserId));
    }

    @Override
    public SocialUserProfileRecord userProfile(String userId) {
        return userProfiles.get(requireText(userId, "userId"));
    }

    @Override
    public SocialUserProfileRecord userProfileByHandle(String handle) {
        String normalizedHandle = requireText(handle, "handle");
        return userProfiles.values().stream()
                .filter(profile -> profile.handle().equals(normalizedHandle))
                .findFirst()
                .orElse(null);
    }

    @Override
    public List<SocialUserProfileRecord> userProfiles() {
        return List.copyOf(userProfiles.values());
    }

    @Override
    public void saveUserProfile(SocialUserProfileRecord profile) {
        userProfiles.put(requireText(profile.userId(), "userId"), profile);
    }

    @Override
    public List<BlockRecord> blocks() {
        return List.copyOf(blocks.values());
    }

    @Override
    public void saveBlock(BlockRecord block) {
        blocks.put(directedKey(block.userId(), block.blockedUserId()), block);
    }

    @Override
    public void removeBlock(String userId, String blockedUserId) {
        blocks.remove(directedKey(userId, blockedUserId));
    }

    @Override
    public SocialMuteRecord mute(String userId, String targetType, String targetId) {
        return mutes.get(muteKey(userId, targetType, targetId));
    }

    @Override
    public List<SocialMuteRecord> mutes() {
        return List.copyOf(mutes.values());
    }

    @Override
    public List<SocialMuteRecord> mutesByUser(String userId) {
        String normalizedUserId = requireText(userId, "userId");
        return mutes.values().stream()
                .filter(mute -> mute.userId().equals(normalizedUserId))
                .toList();
    }

    @Override
    public void saveMute(SocialMuteRecord mute) {
        mutes.put(muteKey(mute.userId(), mute.targetType(), mute.targetId()), mute);
    }

    @Override
    public void removeMute(String userId, String targetType, String targetId) {
        mutes.remove(muteKey(userId, targetType, targetId));
    }

    @Override
    public List<FamilyLinkRecord> familyLinks() {
        return List.copyOf(familyLinks.values());
    }

    @Override
    public void saveFamilyLink(FamilyLinkRecord link) {
        familyLinks.put(friendshipKey(link.firstUserId(), link.secondUserId()), link);
    }

    @Override
    public void removeFamilyLink(String firstUserId, String secondUserId) {
        familyLinks.remove(friendshipKey(firstUserId, secondUserId));
    }

    void clear() {
        friendRequests.clear();
        friendships.clear();
        closeFriends.clear();
        userFollows.clear();
        userFollowRequests.clear();
        userProfiles.clear();
        blocks.clear();
        mutes.clear();
        familyLinks.clear();
    }

    private String friendshipKey(String firstUserId, String secondUserId) {
        String first = requireText(firstUserId, "firstUserId");
        String second = requireText(secondUserId, "secondUserId");
        return first.compareTo(second) <= 0 ? first + "|" + second : second + "|" + first;
    }

    private String directedKey(String ownerId, String targetId) {
        return requireText(ownerId, "ownerId") + "->" + requireText(targetId, "targetId");
    }

    private String muteKey(String userId, String targetType, String targetId) {
        return requireText(userId, "userId")
                + "->"
                + requireText(targetType, "targetType")
                + ":"
                + requireText(targetId, "targetId");
    }
}
