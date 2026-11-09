package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.BlockRequest;
import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipEndpointWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T09:00:00Z");

    @Test
    void hydratesFriendRequestAndCloseFriendWriteResponses() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        List<ActivityEvent> activities = new ArrayList<>();
        SocialRelationshipEndpointWriteModel endpointModel = endpointModel(repository, Set.of(), activities);

        FriendRequestResponse created = endpointModel.createFriendRequest(new FriendRequestCreateRequest(
                "user_a",
                "user_b",
                "walk?"));
        FriendRequestResponse accepted = endpointModel.acceptRequest(created.id(), "user_b");
        FriendSummary closeFriend = endpointModel.addCloseFriend("user_a", "user_b");

        assertEquals("friend_request_1", created.id());
        assertEquals("pending", created.status());
        assertEquals("card_user_a_for_user_a", created.fromUser().displayName());
        assertEquals("accepted", accepted.status());
        assertEquals("card_user_b_for_user_b", accepted.toUser().displayName());
        assertEquals("user_b", closeFriend.userId());
        assertTrue(closeFriend.closeFriend());
        assertEquals("card_user_b_for_user_a", closeFriend.friend().displayName());
        assertEquals(2, activities.size());
        assertEquals("friend_request_received", activities.get(0).eventType());
        assertEquals("friend_request_accepted", activities.get(1).eventType());
    }

    @Test
    void hydratesFollowBlockMuteAndFamilyWriteResponses() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_a", "Group A", "public", BASE_TIME));
        List<ActivityEvent> activities = new ArrayList<>();
        SocialRelationshipEndpointWriteModel endpointModel =
                endpointModel(repository, Set.of("private_owner"), activities);

        SocialUserFollowResponse pending = endpointModel.followUser(
                "private_owner",
                new SocialUserFollowRequest("follower_a"));
        SocialUserFollowResponse approved = endpointModel.decideUserFollowRequest(
                "private_owner",
                "follower_a",
                new SocialUserFollowDecisionRequest("private_owner", "approve"));
        BlockResponse block = endpointModel.block(new BlockRequest("user_a", "user_b", "unsafe"));
        SocialMuteResponse mute = endpointModel.mute(new SocialMuteRequest("user_a", "group", "group_a", "quiet"));
        FamilyLinkResponse family = endpointModel.createFamilyLink(new FamilyLinkCreateRequest(
                "user_a",
                "relative_a",
                "sibling"));

        assertEquals("pending", pending.status());
        assertEquals("card_follower_a_for_follower_a", pending.follower().displayName());
        assertEquals("following", approved.status());
        assertEquals("card_private_owner_for_private_owner", approved.followedUser().displayName());
        assertEquals("user_b", block.blockedUserId());
        assertEquals("quiet", mute.reason());
        assertEquals("sibling", family.relationship());
        assertEquals(2, activities.size());
        assertEquals("follow_requested", activities.get(0).eventType());
        assertEquals("follow_accepted", activities.get(1).eventType());

        endpointModel.unmute("user_a", "group", "group_a");
        endpointModel.removeFamilyLink("user_a", "relative_a");
        endpointModel.unfollowUser("private_owner", "follower_a");

        assertNull(repository.mute("user_a", "group", "group_a"));
        assertTrue(repository.familyLinks().isEmpty());
        assertNull(repository.userFollow("follower_a", "private_owner"));
    }

    private SocialRelationshipEndpointWriteModel endpointModel(
            InMemorySocialGraphRepository repository,
            Set<String> privateUsers,
            List<ActivityEvent> activities) {
        SocialRelationshipPolicy policy = new SocialRelationshipPolicy(repository);
        AtomicReference<Instant> now = new AtomicReference<>(BASE_TIME);
        AtomicInteger ids = new AtomicInteger();
        SocialRelationshipWriteModel writeModel = new SocialRelationshipWriteModel(
                repository,
                policy,
                userId -> profile(userId, privateUsers.contains(userId) ? "private" : "public"),
                userId -> "Label " + userId,
                (eventType, actorUserId, recipientUserId, contentId, commentId, sourceType, message) ->
                        activities.add(new ActivityEvent(eventType, actorUserId, recipientUserId, message)),
                (userId, targetType, targetId) -> validateMuteTarget(repository, userId, targetType, targetId),
                () -> now.getAndUpdate(value -> value.plusSeconds(1)),
                () -> "friend_request_" + ids.incrementAndGet());
        return new SocialRelationshipEndpointWriteModel(
                writeModel,
                new SocialRelationshipPresentationResolver(policy, SocialRelationshipEndpointWriteModelTest::card));
    }

    private static void validateMuteTarget(
            InMemorySocialGraphRepository repository,
            String userId,
            String targetType,
            String targetId) {
        if ("user".equals(targetType)) {
            if (userId.equals(targetId)) {
                throw new BadRequestException("Cannot mute yourself");
            }
            return;
        }
        if ("group".equals(targetType) && repository.group(targetId) == null) {
            throw new BadRequestException("Unknown group");
        }
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

    private static SocialUserProfileCardResponse card(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                "card_" + userId + "_for_" + viewerId,
                userId,
                "",
                "public",
                true);
    }

    private record ActivityEvent(String eventType, String actorUserId, String recipientUserId, String message) {
    }
}
