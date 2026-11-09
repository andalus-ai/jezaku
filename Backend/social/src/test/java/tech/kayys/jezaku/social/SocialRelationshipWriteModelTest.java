package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.BlockRequest;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T12:00:00Z");

    @Test
    void createsAcceptsFriendRequestsAndCloseFriendWrites() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        List<ActivityEvent> activities = new ArrayList<>();
        SocialRelationshipWriteModel model = model(repository, Set.of(), activities);

        FriendRequestRecord created = model.createFriendRequest(new FriendRequestCreateRequest(
                "user_a",
                "user_b",
                "campus trail?"));
        FriendRequestRecord duplicate = model.createFriendRequest(new FriendRequestCreateRequest(
                "user_b",
                "user_a",
                "reverse request"));
        FriendRequestRecord accepted = model.acceptFriendRequest(created.id(), "user_b");
        CloseFriendRecord closeFriend = model.addCloseFriend("user_a", "user_b");

        assertEquals("friend_request_1", created.id());
        assertEquals(created.id(), duplicate.id());
        assertEquals("pending", created.status());
        assertEquals("accepted", accepted.status());
        assertTrue(new SocialRelationshipPolicy(repository).friends("user_a", "user_b"));
        assertEquals("user_b", closeFriend.friendId());
        assertTrue(new SocialRelationshipPolicy(repository).closeFriend("user_a", "user_b"));
        assertEquals(2, activities.size());
        assertEquals("friend_request_received", activities.get(0).eventType());
        assertEquals("user_a", activities.get(0).actorUserId());
        assertEquals("user_b", activities.get(0).recipientUserId());
        assertEquals("Label user_a sent you a friend request.", activities.get(0).message());
        assertEquals("friend_request_accepted", activities.get(1).eventType());
        assertEquals("user_b", activities.get(1).actorUserId());
        assertEquals("user_a", activities.get(1).recipientUserId());
        assertEquals("Label user_b accepted your friend request.", activities.get(1).message());

        model.removeFriend("user_a", "user_b");

        assertFalse(new SocialRelationshipPolicy(repository).friends("user_a", "user_b"));
        assertFalse(new SocialRelationshipPolicy(repository).closeFriend("user_a", "user_b"));
    }

    @Test
    void createsPrivateFollowRequestsAndApprovesThemWithActivity() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        List<ActivityEvent> activities = new ArrayList<>();
        SocialRelationshipWriteModel model = model(repository, Set.of("private_owner"), activities);

        SocialRelationshipWriteModel.SocialUserFollowWriteResult pending = model.followUser(
                "private_owner",
                new SocialUserFollowRequest("follower_a"));
        SocialRelationshipWriteModel.SocialUserFollowWriteResult duplicate = model.followUser(
                "private_owner",
                new SocialUserFollowRequest("follower_a"));
        SocialRelationshipWriteModel.SocialUserFollowWriteResult approved = model.decideUserFollowRequest(
                "private_owner",
                "follower_a",
                new SocialUserFollowDecisionRequest("private_owner", "approve"));

        assertNull(pending.follow());
        assertEquals("pending", pending.request().status());
        assertEquals(pending.request(), duplicate.request());
        assertNotNull(approved.follow());
        assertEquals("follower_a", approved.follow().followerId());
        assertEquals("private_owner", approved.follow().followedUserId());
        assertEquals("accepted", repository.userFollowRequest("follower_a", "private_owner").status());
        assertEquals(2, activities.size());
        assertEquals("follow_requested", activities.get(0).eventType());
        assertEquals("follow_accepted", activities.get(1).eventType());
    }

    @Test
    void blocksAndCleansExistingRelationshipState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialRelationshipWriteModel model = model(repository, Set.of(), new ArrayList<>());
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
        repository.saveFriendRequest(friendRequest("friend_request_ab", "user_a", "user_b"));
        repository.saveFriendRequest(friendRequest("friend_request_ba", "user_b", "user_a"));

        BlockRecord block = model.block(new BlockRequest("user_a", "user_b", "unsafe"));

        assertEquals("user_a", block.userId());
        assertEquals("user_b", block.blockedUserId());
        assertTrue(new SocialRelationshipPolicy(repository).blockedEitherWay("user_a", "user_b"));
        assertFalse(new SocialRelationshipPolicy(repository).friends("user_a", "user_b"));
        assertFalse(new SocialRelationshipPolicy(repository).closeFriend("user_a", "user_b"));
        assertFalse(new SocialRelationshipPolicy(repository).closeFriend("user_b", "user_a"));
        assertNull(repository.userFollow("user_a", "user_b"));
        assertNull(repository.userFollow("user_b", "user_a"));
        assertNull(repository.userFollowRequest("user_a", "user_b"));
        assertNull(repository.userFollowRequest("user_b", "user_a"));
        assertNull(repository.friendRequest("friend_request_ab"));
        assertNull(repository.friendRequest("friend_request_ba"));
    }

    @Test
    void managesMutesAndFamilyLinksWithValidation() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        SocialRelationshipWriteModel model = model(repository, Set.of(), new ArrayList<>());

        SocialMuteRecord firstMute = model.mute(new SocialMuteRequest(
                "user_a",
                "group",
                "group_a",
                "too noisy"));
        SocialMuteRecord updatedMute = model.mute(new SocialMuteRequest(
                "user_a",
                "group",
                "group_a",
                "later"));
        FamilyLinkRecord family = model.createFamilyLink(new FamilyLinkCreateRequest(
                "user_a",
                "relative_a",
                "sibling"));

        assertEquals(firstMute.createdAt(), updatedMute.createdAt());
        assertEquals("later", repository.mute("user_a", "group", "group_a").reason());
        assertEquals("sibling", family.relationship());

        model.removeFamilyLink("user_a", "relative_a");
        model.unmute("user_a", "group", "group_a");

        assertTrue(repository.familyLinks().isEmpty());
        assertNull(repository.mute("user_a", "group", "group_a"));
        assertThrows(BadRequestException.class, () -> model.mute(new SocialMuteRequest(
                "user_a",
                "user",
                "user_a",
                "")));
        repository.saveBlock(new BlockRecord("user_a", "relative_b", "unsafe", BASE_TIME));
        assertThrows(WebApplicationException.class, () -> model.createFamilyLink(new FamilyLinkCreateRequest(
                "user_a",
                "relative_b",
                "cousin")));
    }

    private static SocialRelationshipWriteModel model(
            InMemorySocialGraphRepository repository,
            Set<String> privateUsers,
            List<ActivityEvent> activities) {
        AtomicReference<Instant> now = new AtomicReference<>(BASE_TIME);
        AtomicInteger ids = new AtomicInteger();
        return new SocialRelationshipWriteModel(
                repository,
                new SocialRelationshipPolicy(repository),
                userId -> profile(userId, privateUsers.contains(userId) ? "private" : "public"),
                userId -> "Label " + userId,
                (eventType, actorUserId, recipientUserId, contentId, commentId, sourceType, message) ->
                        activities.add(new ActivityEvent(eventType, actorUserId, recipientUserId, message)),
                new SocialMuteTargetGuard(new SocialGraphEntityResolver(repository)),
                () -> now.getAndUpdate(value -> value.plusSeconds(1)),
                () -> "friend_request_" + ids.incrementAndGet());
    }

    private static FriendRequestRecord friendRequest(String id, String fromUserId, String toUserId) {
        return new FriendRequestRecord(
                id,
                fromUserId,
                toUserId,
                "",
                "pending",
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

    private record ActivityEvent(String eventType, String actorUserId, String recipientUserId, String message) {
    }
}
