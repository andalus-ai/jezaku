package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.BlockListResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.List;
import java.util.function.BiPredicate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipEndpointReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T05:00:00Z");
    private static final String OWNER = "owner_a";

    @Test
    void assemblesFriendAndFollowListResponsesWithHydratedCards() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveFriendRequest(friendRequest("friend_request_in", "friend_candidate", OWNER, "pending", 10));
        repository.saveFriendRequest(friendRequest("friend_request_done", "done_candidate", OWNER, "accepted", 20));
        repository.saveFriendship(OWNER, "friend_a", BASE_TIME.plusSeconds(30));
        repository.saveCloseFriend(OWNER, "friend_close", BASE_TIME.plusSeconds(40));
        repository.saveUserFollowRequest(followRequest("follower_request", OWNER, "pending", 50));
        repository.saveUserFollow(new SocialUserFollowRecord("follower_a", OWNER, BASE_TIME.plusSeconds(60)));
        repository.saveUserFollow(new SocialUserFollowRecord(OWNER, "followed_a", BASE_TIME.plusSeconds(70)));
        SocialRelationshipEndpointReadModel readModel = readModel(repository, (first, second) -> false);

        FriendRequestListResponse friendRequests = readModel.friendRequests(OWNER, null, null, null, "");
        FriendListResponse friends = readModel.friends(OWNER, "viewer_a", null, "");
        FriendListResponse closeFriends = readModel.closeFriends(OWNER, "viewer_a", null, "");
        SocialUserFollowRequestListResponse followRequests =
                readModel.userFollowRequests(OWNER, null, "all", null, "");
        SocialUserFollowListResponse followers = readModel.followers(OWNER, "viewer_a", null, "");
        SocialUserFollowListResponse following = readModel.following(OWNER, "viewer_a", null, "");

        assertEquals("incoming", friendRequests.direction());
        assertEquals("all", friendRequests.status());
        assertEquals(List.of("friend_request_done", "friend_request_in"), friendRequests.requests().stream()
                .map(request -> request.id())
                .toList());
        assertEquals("card_done_candidate_for_owner_a", friendRequests.requests().get(0).fromUser().displayName());
        assertEquals(List.of("friend_a"), friends.friends().stream().map(friend -> friend.userId()).toList());
        assertEquals("card_friend_a_for_viewer_a", friends.friends().get(0).friend().displayName());
        assertEquals(List.of("friend_close"), closeFriends.friends().stream().map(friend -> friend.userId()).toList());
        assertTrue(closeFriends.friends().get(0).closeFriend());
        assertEquals("all", followRequests.status());
        assertEquals(List.of("follower_request"), followRequests.requests().stream()
                .map(request -> request.followerId())
                .toList());
        assertEquals("followers", followers.direction());
        assertEquals(List.of("follower_a"), followers.follows().stream()
                .map(follow -> follow.followerId())
                .toList());
        assertEquals("following", following.direction());
        assertEquals(List.of("followed_a"), following.follows().stream()
                .map(follow -> follow.followedUserId())
                .toList());
    }

    @Test
    void assemblesBlocksMutesAndFamilyWithCursorMetadata() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveBlock(new BlockRecord(OWNER, "blocked_new", "new", BASE_TIME.plusSeconds(20)));
        repository.saveBlock(new BlockRecord(OWNER, "blocked_old", "old", BASE_TIME.plusSeconds(10)));
        repository.saveMute(new SocialMuteRecord(OWNER, "user", "muted_new", "new", BASE_TIME.plusSeconds(20)));
        repository.saveMute(new SocialMuteRecord(OWNER, "user", "muted_old", "old", BASE_TIME.plusSeconds(10)));
        repository.saveMute(new SocialMuteRecord(OWNER, "group", "muted_group", "group", BASE_TIME.plusSeconds(30)));
        repository.saveFamilyLink(new FamilyLinkRecord(OWNER, "relative_new", "sibling", BASE_TIME.plusSeconds(20)));
        repository.saveFamilyLink(new FamilyLinkRecord(OWNER, "relative_old", "guardian", BASE_TIME.plusSeconds(10)));
        SocialRelationshipEndpointReadModel readModel = readModel(repository, (first, second) -> false);

        BlockListResponse blocks = readModel.blocks(OWNER, 1, "");
        SocialMuteListResponse mutes = readModel.mutes(OWNER, "user", 1, "");
        FamilyLinkListResponse family = readModel.family(OWNER, 1, "");

        assertEquals(List.of("blocked_new"), blocks.blocks().stream()
                .map(block -> block.blockedUserId())
                .toList());
        assertTrue(blocks.hasMore());
        assertFalse(blocks.nextCursor().isBlank());
        assertEquals("user", mutes.targetType());
        assertEquals(List.of("muted_new"), mutes.mutes().stream().map(mute -> mute.targetId()).toList());
        assertTrue(mutes.hasMore());
        assertEquals(List.of("relative_new"), family.links().stream()
                .map(link -> link.secondUserId())
                .toList());
        assertTrue(family.hasMore());
    }

    @Test
    void rejectsInvalidEndpointFilters() {
        SocialRelationshipEndpointReadModel readModel =
                readModel(new InMemorySocialGraphRepository(), (first, second) -> false);

        assertThrows(BadRequestException.class, () -> readModel.friendRequests(OWNER, "sideways", null, null, ""));
        assertThrows(BadRequestException.class, () -> readModel.friendRequests(OWNER, null, "archived", null, ""));
        assertThrows(BadRequestException.class, () -> readModel.userFollowRequests(OWNER, null, "ignored", null, ""));
        assertThrows(BadRequestException.class, () -> readModel.mutes(OWNER, "content", null, ""));
    }

    private SocialRelationshipEndpointReadModel readModel(
            InMemorySocialGraphRepository repository,
            BiPredicate<String, String> blockedEitherWay) {
        SocialRelationshipPolicy policy = new SocialRelationshipPolicy(repository);
        SocialRelationshipReadModel relationshipReadModel = new SocialRelationshipReadModel(
                repository,
                policy,
                new SocialChronologicalPaginationPlanner(),
                blockedEitherWay);
        SocialRelationshipPresentationResolver presentationResolver =
                new SocialRelationshipPresentationResolver(policy, SocialRelationshipEndpointReadModelTest::card);
        return new SocialRelationshipEndpointReadModel(
                relationshipReadModel,
                presentationResolver,
                new SocialRelationshipEndpointReadModel.Limits(100, 100, 100, 100, 100, 100, 100));
    }

    private static SocialUserProfileCardResponse card(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                "card_" + userId + "_for_" + viewerId,
                "handle_" + userId,
                "",
                "public",
                true);
    }

    private FriendRequestRecord friendRequest(
            String id,
            String fromUserId,
            String toUserId,
            String status,
            long seconds) {
        return new FriendRequestRecord(
                id,
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
            long seconds) {
        return new SocialUserFollowRequestRecord(
                followerId,
                followedUserId,
                status,
                BASE_TIME.plusSeconds(seconds),
                BASE_TIME.plusSeconds(seconds));
    }
}
