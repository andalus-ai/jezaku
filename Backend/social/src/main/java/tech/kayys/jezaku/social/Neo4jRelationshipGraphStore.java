package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_BLOCK;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_CLOSE_FRIEND;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_FAMILY_LINK;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_FRIENDSHIP;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_FRIEND_REQUEST;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_MUTE;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_USER_FOLLOW;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.DELETE_USER_FOLLOW_REQUEST;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_BLOCKS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_CLOSE_FRIENDS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_FAMILY_LINKS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_FOLLOWERS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_FOLLOWING;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_FRIENDSHIPS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_FRIEND_REQUEST;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_FRIEND_REQUESTS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_MUTE;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_MUTES;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_MUTES_BY_USER;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_FOLLOW;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_FOLLOWS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_FOLLOW_REQUEST;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_FOLLOW_REQUESTS;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_PROFILE;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_PROFILE_BY_HANDLE;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.READ_USER_PROFILES;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_BLOCK;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_CLOSE_FRIEND;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_FAMILY_LINK;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_FRIENDSHIP;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_FRIEND_REQUEST;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_USER_FOLLOW;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_USER_FOLLOW_REQUEST;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.SAVE_USER_PROFILE;
import static tech.kayys.jezaku.social.Neo4jRelationshipCypher.muteSaveStatement;
import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Persists Neo4j relationship, profile, block, mute, and family graph records.
 */
final class Neo4jRelationshipGraphStore extends Neo4jGraphStoreSupport implements SocialRelationshipGraphStore {
    private final Neo4jRelationshipRecordMapper mapper = new Neo4jRelationshipRecordMapper();

    Neo4jRelationshipGraphStore(Neo4jSocialGraphClient client) {
        super(client);
    }

    @Override
    public FriendRequestRecord friendRequest(String requestId) {
        return readOne(READ_FRIEND_REQUEST, Map.of("requestId", requireText(requestId, "requestId")),
                mapper::friendRequest);
    }

    @Override
    public List<FriendRequestRecord> friendRequests() {
        return readList(READ_FRIEND_REQUESTS, Map.of(), mapper::friendRequest);
    }

    @Override
    public void saveFriendRequest(FriendRequestRecord request) {
        write(SAVE_FRIEND_REQUEST, mapper.friendRequestParameters(request));
    }

    @Override
    public void removeFriendRequest(String requestId) {
        write(DELETE_FRIEND_REQUEST, Map.of("requestId", requireText(requestId, "requestId")));
    }

    @Override
    public List<FriendshipRecord> friendships() {
        return readList(READ_FRIENDSHIPS, Map.of(), mapper::friendship);
    }

    @Override
    public void saveFriendship(String firstUserId, String secondUserId, Instant createdAt) {
        UserPair pair = orderedPair(firstUserId, secondUserId);
        write(SAVE_FRIENDSHIP, Map.of(
                "firstUserId", pair.firstUserId(),
                "secondUserId", pair.secondUserId(),
                "createdAt", iso(createdAt)));
    }

    @Override
    public void removeFriendship(String firstUserId, String secondUserId) {
        UserPair pair = orderedPair(firstUserId, secondUserId);
        write(DELETE_FRIENDSHIP, Map.of(
                "firstUserId", pair.firstUserId(),
                "secondUserId", pair.secondUserId()));
    }

    @Override
    public List<CloseFriendRecord> closeFriends() {
        return readList(READ_CLOSE_FRIENDS, Map.of(), mapper::closeFriend);
    }

    @Override
    public void saveCloseFriend(String ownerId, String friendId, Instant createdAt) {
        write(SAVE_CLOSE_FRIEND, Map.of(
                "ownerId", requireText(ownerId, "ownerId"),
                "friendId", requireText(friendId, "friendId"),
                "createdAt", iso(createdAt)));
    }

    @Override
    public void removeCloseFriend(String ownerId, String friendId) {
        write(DELETE_CLOSE_FRIEND, Map.of(
                "ownerId", requireText(ownerId, "ownerId"),
                "friendId", requireText(friendId, "friendId")));
    }

    @Override
    public SocialUserFollowRecord userFollow(String followerId, String followedUserId) {
        return readOne(READ_USER_FOLLOW, Map.of(
                "followerId", requireText(followerId, "followerId"),
                "followedUserId", requireText(followedUserId, "followedUserId")),
                mapper::userFollow);
    }

    @Override
    public List<SocialUserFollowRecord> userFollows() {
        return readList(READ_USER_FOLLOWS, Map.of(), mapper::userFollow);
    }

    @Override
    public List<SocialUserFollowRecord> followers(String userId) {
        return readList(READ_FOLLOWERS, Map.of("userId", requireText(userId, "userId")),
                mapper::userFollow);
    }

    @Override
    public List<SocialUserFollowRecord> following(String userId) {
        return readList(READ_FOLLOWING, Map.of("userId", requireText(userId, "userId")),
                mapper::userFollow);
    }

    @Override
    public void saveUserFollow(SocialUserFollowRecord follow) {
        write(SAVE_USER_FOLLOW, mapper.userFollowParameters(follow));
    }

    @Override
    public void removeUserFollow(String followerId, String followedUserId) {
        write(DELETE_USER_FOLLOW, Map.of(
                "followerId", requireText(followerId, "followerId"),
                "followedUserId", requireText(followedUserId, "followedUserId")));
    }

    @Override
    public SocialUserFollowRequestRecord userFollowRequest(String followerId, String followedUserId) {
        return readOne(READ_USER_FOLLOW_REQUEST, Map.of(
                "followerId", requireText(followerId, "followerId"),
                "followedUserId", requireText(followedUserId, "followedUserId")),
                mapper::userFollowRequest);
    }

    @Override
    public List<SocialUserFollowRequestRecord> userFollowRequests() {
        return readList(READ_USER_FOLLOW_REQUESTS, Map.of(), mapper::userFollowRequest);
    }

    @Override
    public void saveUserFollowRequest(SocialUserFollowRequestRecord request) {
        write(SAVE_USER_FOLLOW_REQUEST, mapper.userFollowRequestParameters(request));
    }

    @Override
    public void removeUserFollowRequest(String followerId, String followedUserId) {
        write(DELETE_USER_FOLLOW_REQUEST, Map.of(
                "followerId", requireText(followerId, "followerId"),
                "followedUserId", requireText(followedUserId, "followedUserId")));
    }

    @Override
    public SocialUserProfileRecord userProfile(String userId) {
        return readOne(READ_USER_PROFILE, Map.of("userId", requireText(userId, "userId")),
                mapper::userProfile);
    }

    @Override
    public SocialUserProfileRecord userProfileByHandle(String handle) {
        return readOne(READ_USER_PROFILE_BY_HANDLE, Map.of("handle", requireText(handle, "handle")),
                mapper::userProfile);
    }

    @Override
    public List<SocialUserProfileRecord> userProfiles() {
        return readList(READ_USER_PROFILES, Map.of(), mapper::userProfile);
    }

    @Override
    public void saveUserProfile(SocialUserProfileRecord profile) {
        write(SAVE_USER_PROFILE, mapper.userProfileParameters(profile));
    }

    @Override
    public List<BlockRecord> blocks() {
        return readList(READ_BLOCKS, Map.of(), mapper::block);
    }

    @Override
    public void saveBlock(BlockRecord block) {
        write(SAVE_BLOCK, mapper.blockParameters(block));
    }

    @Override
    public void removeBlock(String userId, String blockedUserId) {
        write(DELETE_BLOCK, Map.of(
                "userId", requireText(userId, "userId"),
                "blockedUserId", requireText(blockedUserId, "blockedUserId")));
    }

    @Override
    public SocialMuteRecord mute(String userId, String targetType, String targetId) {
        return readOne(READ_MUTE, Map.of(
                "userId", requireText(userId, "userId"),
                "targetType", requireText(targetType, "targetType"),
                "targetId", requireText(targetId, "targetId")), mapper::mute);
    }

    @Override
    public List<SocialMuteRecord> mutes() {
        return readList(READ_MUTES, Map.of(), mapper::mute);
    }

    @Override
    public List<SocialMuteRecord> mutesByUser(String userId) {
        return readList(READ_MUTES_BY_USER, Map.of("userId", requireText(userId, "userId")),
                mapper::mute);
    }

    @Override
    public void saveMute(SocialMuteRecord mute) {
        write(muteSaveStatement(mute), mapper.muteParameters(mute));
    }

    @Override
    public void removeMute(String userId, String targetType, String targetId) {
        write(DELETE_MUTE, Map.of(
                "userId", requireText(userId, "userId"),
                "targetType", requireText(targetType, "targetType"),
                "targetId", requireText(targetId, "targetId")));
    }

    @Override
    public List<FamilyLinkRecord> familyLinks() {
        return readList(READ_FAMILY_LINKS, Map.of(), mapper::familyLink);
    }

    @Override
    public void saveFamilyLink(FamilyLinkRecord link) {
        UserPair pair = orderedPair(link.firstUserId(), link.secondUserId());
        write(SAVE_FAMILY_LINK, Map.of(
                "firstUserId", pair.firstUserId(),
                "secondUserId", pair.secondUserId(),
                "relationship", link.relationship(),
                "createdAt", iso(link.createdAt())));
    }

    @Override
    public void removeFamilyLink(String firstUserId, String secondUserId) {
        UserPair pair = orderedPair(firstUserId, secondUserId);
        write(DELETE_FAMILY_LINK, Map.of(
                "firstUserId", pair.firstUserId(),
                "secondUserId", pair.secondUserId()));
    }

    private UserPair orderedPair(String firstUserId, String secondUserId) {
        String first = requireText(firstUserId, "firstUserId");
        String second = requireText(secondUserId, "secondUserId");
        return first.compareTo(second) <= 0 ? new UserPair(first, second) : new UserPair(second, first);
    }

    private record UserPair(String firstUserId, String secondUserId) {
    }
}
