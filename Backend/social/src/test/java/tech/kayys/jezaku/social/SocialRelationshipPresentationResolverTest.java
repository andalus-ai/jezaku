package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipPresentationResolverTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T10:00:00Z");

    @Test
    void hydratesFriendSummaryAndFriendRequestWithProfileCards() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveCloseFriend("user_a", "user_b", BASE_TIME.plusSeconds(1));
        SocialRelationshipPresentationResolver resolver = resolver(repository);
        FriendshipRecord friendship = new FriendshipRecord("user_a", "user_b", BASE_TIME);
        FriendRequestRecord request = new FriendRequestRecord(
                "friend_request_a",
                "user_c",
                "user_d",
                "hello",
                "pending",
                BASE_TIME.plusSeconds(2),
                BASE_TIME.plusSeconds(3));

        FriendSummary summary = resolver.friend(friendship, "user_a", "viewer");
        FriendRequestResponse response = resolver.friendRequest(request, "viewer");

        assertEquals("user_b", summary.userId());
        assertTrue(summary.closeFriend());
        assertEquals("display_user_b_for_viewer", summary.friend().displayName());
        assertEquals("friend_request_a", response.id());
        assertEquals("user_c", response.fromUserId());
        assertEquals("display_user_c_for_viewer", response.fromUser().displayName());
        assertEquals("display_user_d_for_viewer", response.toUser().displayName());
    }

    @Test
    void hydratesFollowAndFollowRequestResponses() {
        SocialRelationshipPresentationResolver resolver = resolver(new InMemorySocialGraphRepository());
        SocialUserFollowRecord follow = new SocialUserFollowRecord(
                "follower",
                "followed",
                BASE_TIME.plusSeconds(4));
        SocialUserFollowRequestRecord request = new SocialUserFollowRequestRecord(
                "candidate",
                "private_user",
                "pending",
                BASE_TIME.plusSeconds(5),
                BASE_TIME.plusSeconds(6));

        SocialUserFollowResponse followResponse = resolver.follow(follow, "viewer");
        SocialUserFollowResponse requestResponse = resolver.followRequest(request, "viewer");

        assertEquals("following", followResponse.status());
        assertEquals(BASE_TIME.plusSeconds(4), followResponse.updatedAt());
        assertEquals("display_follower_for_viewer", followResponse.follower().displayName());
        assertEquals("display_followed_for_viewer", followResponse.followedUser().displayName());
        assertEquals("pending", requestResponse.status());
        assertEquals(BASE_TIME.plusSeconds(6), requestResponse.updatedAt());
        assertEquals("display_candidate_for_viewer", requestResponse.follower().displayName());
        assertEquals("display_private_user_for_viewer", requestResponse.followedUser().displayName());
    }

    @Test
    void hydratesSimpleRelationshipRecords() {
        SocialRelationshipPresentationResolver resolver = resolver(new InMemorySocialGraphRepository());
        BlockRecord block = new BlockRecord("user_a", "user_b", "spam", BASE_TIME);
        SocialMuteRecord mute = new SocialMuteRecord("user_a", "group", "group_a", "quiet", BASE_TIME.plusSeconds(3));
        FamilyLinkRecord family = new FamilyLinkRecord(
                "user_a",
                "user_c",
                "sibling",
                BASE_TIME.plusSeconds(1));

        BlockResponse blockResponse = resolver.block(block);
        SocialMuteResponse muteResponse = resolver.mute(mute);
        FamilyLinkResponse familyResponse = resolver.family(family);
        FriendSummary explicitFriend = resolver.friend("user_d", BASE_TIME.plusSeconds(2), false, "viewer");

        assertEquals("user_a", blockResponse.userId());
        assertEquals("user_b", blockResponse.blockedUserId());
        assertEquals("spam", blockResponse.reason());
        assertEquals("group", muteResponse.targetType());
        assertEquals("group_a", muteResponse.targetId());
        assertEquals("quiet", muteResponse.reason());
        assertEquals("sibling", familyResponse.relationship());
        assertEquals("user_d", explicitFriend.userId());
        assertFalse(explicitFriend.closeFriend());
        assertEquals("display_user_d_for_viewer", explicitFriend.friend().displayName());
    }

    private static SocialRelationshipPresentationResolver resolver(InMemorySocialGraphRepository repository) {
        return new SocialRelationshipPresentationResolver(
                new SocialRelationshipPolicy(repository),
                SocialRelationshipPresentationResolverTest::card);
    }

    private static SocialUserProfileCardResponse card(String userId, String viewerId) {
        return new SocialUserProfileCardResponse(
                userId,
                "display_" + userId + "_for_" + viewerId,
                "handle_" + userId,
                "",
                "public",
                true);
    }
}
