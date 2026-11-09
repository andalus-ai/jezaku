package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.BlockResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.Objects;
import java.util.function.BiFunction;

final class SocialRelationshipPresentationResolver {
    private final SocialRelationshipPolicy relationshipPolicy;
    private final BiFunction<String, String, SocialUserProfileCardResponse> userCard;

    SocialRelationshipPresentationResolver(
            SocialRelationshipPolicy relationshipPolicy,
            BiFunction<String, String, SocialUserProfileCardResponse> userCard) {
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        this.userCard = Objects.requireNonNull(userCard, "userCard");
    }

    FriendSummary friend(FriendshipRecord friendship, String userId, String viewerId) {
        String friendId = friendship.firstUserId().equals(userId)
                ? friendship.secondUserId()
                : friendship.firstUserId();
        return friend(
                friendId,
                friendship.createdAt(),
                relationshipPolicy.closeFriend(userId, friendId),
                viewerId);
    }

    FriendSummary friend(String friendId, Instant friendsSince, boolean closeFriend, String viewerId) {
        return new FriendSummary(
                friendId,
                friendsSince,
                closeFriend,
                userCard.apply(friendId, viewerId));
    }

    FriendRequestResponse friendRequest(FriendRequestRecord request, String viewerId) {
        return new FriendRequestResponse(
                request.id(),
                request.fromUserId(),
                request.toUserId(),
                request.message(),
                request.status(),
                request.createdAt(),
                request.updatedAt(),
                userCard.apply(request.fromUserId(), viewerId),
                userCard.apply(request.toUserId(), viewerId));
    }

    SocialUserFollowResponse follow(SocialUserFollowRecord follow, String viewerId) {
        return new SocialUserFollowResponse(
                follow.followerId(),
                follow.followedUserId(),
                "following",
                follow.createdAt(),
                follow.createdAt(),
                userCard.apply(follow.followerId(), viewerId),
                userCard.apply(follow.followedUserId(), viewerId));
    }

    SocialUserFollowResponse followRequest(SocialUserFollowRequestRecord request, String viewerId) {
        return new SocialUserFollowResponse(
                request.followerId(),
                request.followedUserId(),
                request.status(),
                request.createdAt(),
                request.updatedAt(),
                userCard.apply(request.followerId(), viewerId),
                userCard.apply(request.followedUserId(), viewerId));
    }

    BlockResponse block(BlockRecord block) {
        return new BlockResponse(block.userId(), block.blockedUserId(), block.reason(), block.createdAt());
    }

    SocialMuteResponse mute(SocialMuteRecord mute) {
        return new SocialMuteResponse(
                mute.userId(),
                mute.targetType(),
                mute.targetId(),
                mute.reason(),
                mute.createdAt());
    }

    FamilyLinkResponse family(FamilyLinkRecord link) {
        return new FamilyLinkResponse(
                link.firstUserId(),
                link.secondUserId(),
                link.relationship(),
                link.createdAt());
    }
}
