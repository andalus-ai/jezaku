package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T11:15:00Z");
    private static final String OWNER = "owner_a";

    @Test
    void pagesFriendRequestsFriendsAndCloseFriends() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendRequest(friendRequest("incoming_old", "user_old", OWNER, "pending", 10));
        repository.saveFriendRequest(friendRequest("incoming_new", "user_new", OWNER, "pending", 20));
        repository.saveFriendRequest(friendRequest("outgoing_skip", OWNER, "user_out", "pending", 30));
        repository.saveFriendRequest(friendRequest("accepted_skip", "user_done", OWNER, "accepted", 40));
        repository.saveFriendship(OWNER, "friend_old", BASE_TIME.plusSeconds(10));
        repository.saveFriendship("friend_new", OWNER, BASE_TIME.plusSeconds(20));
        repository.saveFriendship("other_a", "other_b", BASE_TIME.plusSeconds(30));
        repository.saveCloseFriend(OWNER, "close_old", BASE_TIME.plusSeconds(10));
        repository.saveCloseFriend(OWNER, "close_new", BASE_TIME.plusSeconds(20));
        repository.saveCloseFriend("other_owner", "close_skip", BASE_TIME.plusSeconds(30));
        SocialRelationshipReadModel readModel = readModel(repository, (first, second) -> false);

        SocialRelationshipReadModel.RelationshipPage<FriendRequestRecord> firstRequestPage =
                readModel.friendRequests(OWNER, "incoming", "pending", 1, "");
        SocialRelationshipReadModel.RelationshipPage<FriendRequestRecord> secondRequestPage =
                readModel.friendRequests(OWNER, "incoming", "pending", 1, firstRequestPage.nextCursor());
        SocialRelationshipReadModel.RelationshipPage<FriendshipRecord> friendsPage =
                readModel.friends(OWNER, 10, "");
        SocialRelationshipReadModel.RelationshipPage<CloseFriendRecord> closeFriendsPage =
                readModel.closeFriends(OWNER, 10, "");

        assertEquals(List.of("incoming_new"), friendRequestIds(firstRequestPage));
        assertTrue(firstRequestPage.hasMore());
        assertEquals(List.of("incoming_old"), friendRequestIds(secondRequestPage));
        assertFalse(secondRequestPage.hasMore());
        assertEquals(List.of("friend_new", "friend_old"), friendshipFriendIds(friendsPage));
        assertEquals(List.of("close_new", "close_old"), closeFriendIds(closeFriendsPage));
    }

    @Test
    void pagesFollowRequestsFollowersAndFollowing() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveUserFollowRequest(followRequest("follower_old", OWNER, "pending", 10, 10));
        repository.saveUserFollowRequest(followRequest("follower_new", OWNER, "pending", 20, 20));
        repository.saveUserFollowRequest(followRequest(OWNER, "followed_skip", "pending", 30, 30));
        repository.saveUserFollowRequest(followRequest("follower_done", OWNER, "accepted", 40, 40));
        repository.saveUserFollow(new SocialUserFollowRecord("follower_old", OWNER, BASE_TIME.plusSeconds(10)));
        repository.saveUserFollow(new SocialUserFollowRecord("follower_new", OWNER, BASE_TIME.plusSeconds(20)));
        repository.saveUserFollow(new SocialUserFollowRecord(OWNER, "followed_old", BASE_TIME.plusSeconds(10)));
        repository.saveUserFollow(new SocialUserFollowRecord(OWNER, "followed_new", BASE_TIME.plusSeconds(20)));
        SocialRelationshipReadModel readModel = readModel(repository, (first, second) -> false);

        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRequestRecord> firstRequestPage =
                readModel.userFollowRequests(OWNER, "incoming", "pending", 1, "");
        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRequestRecord> secondRequestPage =
                readModel.userFollowRequests(OWNER, "incoming", "pending", 1, firstRequestPage.nextCursor());
        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRecord> followersPage =
                readModel.followers(OWNER, 10, "");
        SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRecord> followingPage =
                readModel.following(OWNER, 10, "");

        assertEquals(List.of("follower_new"), followRequestFollowerIds(firstRequestPage));
        assertTrue(firstRequestPage.hasMore());
        assertEquals(List.of("follower_old"), followRequestFollowerIds(secondRequestPage));
        assertEquals(List.of("follower_new", "follower_old"), followerIds(followersPage));
        assertEquals(List.of("followed_new", "followed_old"), followedIds(followingPage));
    }

    @Test
    void pagesBlocksMutesAndFamilyLinksWithFilters() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveBlock(new BlockRecord(OWNER, "blocked_old", "old", BASE_TIME.plusSeconds(10)));
        repository.saveBlock(new BlockRecord(OWNER, "blocked_new", "new", BASE_TIME.plusSeconds(20)));
        repository.saveBlock(new BlockRecord("other_owner", "blocked_skip", "skip", BASE_TIME.plusSeconds(30)));
        repository.saveMute(new SocialMuteRecord(OWNER, "user", "mute_old", "old", BASE_TIME.plusSeconds(10)));
        repository.saveMute(new SocialMuteRecord(OWNER, "user", "mute_new", "new", BASE_TIME.plusSeconds(20)));
        repository.saveMute(new SocialMuteRecord(OWNER, "group", "mute_skip", "skip", BASE_TIME.plusSeconds(30)));
        repository.saveFamilyLink(new FamilyLinkRecord(OWNER, "relative_old", "sibling", BASE_TIME.plusSeconds(10)));
        repository.saveFamilyLink(new FamilyLinkRecord("relative_new", OWNER, "parent", BASE_TIME.plusSeconds(20)));
        repository.saveFamilyLink(new FamilyLinkRecord(OWNER, "blocked_relative", "cousin", BASE_TIME.plusSeconds(30)));
        SocialRelationshipReadModel readModel =
                readModel(repository, (first, second) -> "blocked_relative".equals(second));

        SocialRelationshipReadModel.RelationshipPage<BlockRecord> firstBlockPage =
                readModel.blocks(OWNER, 1, "");
        SocialRelationshipReadModel.RelationshipPage<BlockRecord> secondBlockPage =
                readModel.blocks(OWNER, 1, firstBlockPage.nextCursor());
        SocialRelationshipReadModel.RelationshipPage<SocialMuteRecord> mutePage =
                readModel.mutes(OWNER, "user", 10, "");
        SocialRelationshipReadModel.RelationshipPage<FamilyLinkRecord> familyPage =
                readModel.family(OWNER, 10, "");

        assertEquals(List.of("blocked_new"), blockedUserIds(firstBlockPage));
        assertTrue(firstBlockPage.hasMore());
        assertEquals(List.of("blocked_old"), blockedUserIds(secondBlockPage));
        assertEquals(List.of("mute_new", "mute_old"), muteTargetIds(mutePage));
        assertEquals(List.of("relative_new", "relative_old"), familyRelativeIds(familyPage));
    }

    private SocialRelationshipReadModel readModel(
            InMemorySocialGraphRepository repository,
            BiPredicate<String, String> blockedEitherWay) {
        return new SocialRelationshipReadModel(
                repository,
                new SocialRelationshipPolicy(repository),
                new SocialChronologicalPaginationPlanner(),
                blockedEitherWay);
    }

    private FriendRequestRecord friendRequest(
            String requestId,
            String fromUserId,
            String toUserId,
            String status,
            long seconds) {
        return new FriendRequestRecord(
                requestId,
                fromUserId,
                toUserId,
                "",
                status,
                BASE_TIME.plusSeconds(seconds),
                BASE_TIME.plusSeconds(seconds));
    }

    private SocialUserFollowRequestRecord followRequest(
            String followerId,
            String followedUserId,
            String status,
            long createdSeconds,
            long updatedSeconds) {
        return new SocialUserFollowRequestRecord(
                followerId,
                followedUserId,
                status,
                BASE_TIME.plusSeconds(createdSeconds),
                BASE_TIME.plusSeconds(updatedSeconds));
    }

    private List<String> friendRequestIds(
            SocialRelationshipReadModel.RelationshipPage<FriendRequestRecord> page) {
        return page.items().stream().map(FriendRequestRecord::id).toList();
    }

    private List<String> friendshipFriendIds(
            SocialRelationshipReadModel.RelationshipPage<FriendshipRecord> page) {
        return page.items().stream()
                .map(friendship -> friendship.firstUserId().equals(OWNER)
                        ? friendship.secondUserId()
                        : friendship.firstUserId())
                .toList();
    }

    private List<String> closeFriendIds(
            SocialRelationshipReadModel.RelationshipPage<CloseFriendRecord> page) {
        return page.items().stream().map(CloseFriendRecord::friendId).toList();
    }

    private List<String> followRequestFollowerIds(
            SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRequestRecord> page) {
        return page.items().stream().map(SocialUserFollowRequestRecord::followerId).toList();
    }

    private List<String> followerIds(
            SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRecord> page) {
        return page.items().stream().map(SocialUserFollowRecord::followerId).toList();
    }

    private List<String> followedIds(
            SocialRelationshipReadModel.RelationshipPage<SocialUserFollowRecord> page) {
        return page.items().stream().map(SocialUserFollowRecord::followedUserId).toList();
    }

    private List<String> blockedUserIds(
            SocialRelationshipReadModel.RelationshipPage<BlockRecord> page) {
        return page.items().stream().map(BlockRecord::blockedUserId).toList();
    }

    private List<String> muteTargetIds(
            SocialRelationshipReadModel.RelationshipPage<SocialMuteRecord> page) {
        return page.items().stream().map(SocialMuteRecord::targetId).toList();
    }

    private List<String> familyRelativeIds(
            SocialRelationshipReadModel.RelationshipPage<FamilyLinkRecord> page) {
        return page.items().stream()
                .map(link -> link.firstUserId().equals(OWNER) ? link.secondUserId() : link.firstUserId())
                .toList();
    }
}
