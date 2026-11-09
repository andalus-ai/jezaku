package tech.kayys.jezaku.social;

import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipPolicyTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T09:00:00Z");

    @Test
    void resolvesBlocksFriendshipCloseFriendsAndPendingRequests() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRelationshipPolicy policy = new SocialRelationshipPolicy(repository);
        repository.saveFriendship("user_a", "user_b", BASE_TIME);
        repository.saveCloseFriend("user_a", "user_b", BASE_TIME.plusSeconds(1));
        repository.saveFriendRequest(friendRequest("friend_request_ab", "user_c", "user_d", "pending"));
        repository.saveFriendRequest(friendRequest("friend_request_done", "user_c", "user_e", "accepted"));
        repository.saveBlock(new BlockRecord("blocker", "blocked", "spam", BASE_TIME.plusSeconds(2)));

        assertTrue(policy.friends("user_a", "user_b"));
        assertTrue(policy.friends("user_b", "user_a"));
        assertTrue(policy.closeFriend("user_a", "user_b"));
        assertFalse(policy.closeFriend("user_b", "user_a"));
        assertTrue(policy.blockedEitherWay("blocker", "blocked"));
        assertTrue(policy.blockedEitherWay("blocked", "blocker"));
        assertThrows(WebApplicationException.class, () -> policy.ensureNotBlocked("blocker", "blocked"));
        assertEquals(
                "friend_request_ab",
                policy.pendingFriendRequestBetween("user_d", "user_c").id());
        assertNull(policy.pendingFriendRequestBetween("user_c", "user_e"));
        assertEquals(1, policy.pendingFriendRequestsTo("user_d"));
        assertEquals(1, policy.pendingFriendRequestsFrom("user_c"));
    }

    @Test
    void matchesFriendAndFollowRequestDirectionsAndApprovalRules() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRelationshipPolicy policy = new SocialRelationshipPolicy(repository);
        FriendRequestRecord friendRequest = friendRequest("friend_request_ab", "sender", "recipient", "pending");
        SocialUserFollowRequestRecord followRequest = new SocialUserFollowRequestRecord(
                "follower",
                "followed",
                "pending",
                BASE_TIME,
                BASE_TIME.plusSeconds(1));
        SocialUserProfileRecord privateProfile = profile("followed", "private");
        SocialUserProfileRecord publicProfile = profile("public_user", "public");

        assertTrue(policy.friendRequestMatchesDirection(friendRequest, "recipient", "incoming"));
        assertFalse(policy.friendRequestMatchesDirection(friendRequest, "recipient", "outgoing"));
        assertTrue(policy.friendRequestMatchesDirection(friendRequest, "sender", "outgoing"));
        assertTrue(policy.friendRequestMatchesDirection(friendRequest, "sender", "all"));
        assertTrue(policy.friendRequestMatchesStatus(friendRequest, "all"));
        assertTrue(policy.friendRequestMatchesStatus(friendRequest, "pending"));
        assertFalse(policy.friendRequestMatchesStatus(friendRequest, "accepted"));

        assertTrue(policy.userFollowRequestMatchesDirection(followRequest, "followed", "incoming"));
        assertFalse(policy.userFollowRequestMatchesDirection(followRequest, "followed", "outgoing"));
        assertTrue(policy.userFollowRequestMatchesDirection(followRequest, "follower", "outgoing"));
        assertTrue(policy.userFollowRequestMatchesDirection(followRequest, "follower", "all"));

        assertTrue(policy.followRequiresApproval("follower", "followed", privateProfile));
        assertFalse(policy.followRequiresApproval("follower", "public_user", publicProfile));
        repository.saveFriendship("follower", "followed", BASE_TIME);
        assertFalse(policy.followRequiresApproval("follower", "followed", privateProfile));
    }

    @Test
    void removesRelationshipStateWhenBlocking() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRelationshipPolicy policy = new SocialRelationshipPolicy(repository);
        repository.saveFriendship("user_a", "user_b", BASE_TIME);
        repository.saveCloseFriend("user_a", "user_b", BASE_TIME.plusSeconds(1));
        repository.saveCloseFriend("user_b", "user_a", BASE_TIME.plusSeconds(2));
        repository.saveUserFollow(new SocialUserFollowRecord("user_a", "user_b", BASE_TIME.plusSeconds(3)));
        repository.saveUserFollow(new SocialUserFollowRecord("user_b", "user_a", BASE_TIME.plusSeconds(4)));
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "user_a",
                "user_b",
                "pending",
                BASE_TIME.plusSeconds(5),
                BASE_TIME.plusSeconds(5)));
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "user_b",
                "user_a",
                "pending",
                BASE_TIME.plusSeconds(6),
                BASE_TIME.plusSeconds(6)));
        repository.saveFriendRequest(friendRequest("friend_request_ab", "user_a", "user_b", "pending"));
        repository.saveFriendRequest(friendRequest("friend_request_ba", "user_b", "user_a", "pending"));
        repository.saveFriendRequest(friendRequest("friend_request_ac", "user_a", "user_c", "pending"));

        policy.removeRelationshipState("user_a", "user_b");

        assertFalse(policy.friends("user_a", "user_b"));
        assertFalse(policy.closeFriend("user_a", "user_b"));
        assertFalse(policy.closeFriend("user_b", "user_a"));
        assertNull(repository.userFollow("user_a", "user_b"));
        assertNull(repository.userFollow("user_b", "user_a"));
        assertNull(repository.userFollowRequest("user_a", "user_b"));
        assertNull(repository.userFollowRequest("user_b", "user_a"));
        assertNull(repository.friendRequest("friend_request_ab"));
        assertNull(repository.friendRequest("friend_request_ba"));
        assertEquals("friend_request_ac", repository.friendRequest("friend_request_ac").id());
    }

    private static FriendRequestRecord friendRequest(String id, String from, String to, String status) {
        return new FriendRequestRecord(
                id,
                from,
                to,
                "",
                status,
                BASE_TIME,
                BASE_TIME);
    }

    private static SocialUserProfileRecord profile(String userId, String visibility) {
        return new SocialUserProfileRecord(
                userId,
                userId,
                userId,
                "",
                "",
                "",
                "",
                visibility,
                BASE_TIME,
                BASE_TIME);
    }
}
