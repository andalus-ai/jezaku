package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;

import java.time.Instant;
import java.util.Objects;
import java.util.function.BiFunction;

final class SocialUserProfileSummaryResolver {
    private final SocialGraphRepository repository;
    private final SocialUserProfileResolver profileResolver;
    private final SocialUserStatsResolver userStatsResolver;
    private final BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext;

    SocialUserProfileSummaryResolver(
            SocialGraphRepository repository,
            SocialUserProfileResolver profileResolver,
            SocialUserStatsResolver userStatsResolver,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.profileResolver = Objects.requireNonNull(profileResolver, "profileResolver");
        this.userStatsResolver = Objects.requireNonNull(userStatsResolver, "userStatsResolver");
        this.relationshipContext = Objects.requireNonNull(relationshipContext, "relationshipContext");
    }

    SocialUserProfileSummaryResponse summary(String userId, String viewerId) {
        SocialUserProfileRecord profile = profileResolver.profileFor(userId);
        SocialRelationshipContextResponse context = relationshipContext.apply(viewerId, userId);
        boolean hiddenByBlock = context.blocked() && !viewerId.equals(userId);
        FollowState viewerFollowState = viewerFollowState(viewerId, userId, hiddenByBlock);
        boolean profileVisible = profileResolver.visibleTo(viewerId, userId, profile);
        return new SocialUserProfileSummaryResponse(
                userId,
                viewerId,
                profile.displayName(),
                profile.handle(),
                profileVisible ? profile.bio() : "",
                profileVisible ? profile.avatarUrl() : "",
                profileVisible ? profile.websiteUrl() : "",
                profileVisible ? profile.locationLabel() : "",
                profile.profileVisibility(),
                profile.updatedAt(),
                context.relation(),
                viewerId.equals(userId),
                "following".equals(viewerFollowState.status()),
                viewerFollowState.status(),
                viewerFollowState.updatedAt(),
                context.directFriend(),
                context.blocked(),
                hiddenByBlock ? 0 : friendCount(userId),
                hiddenByBlock ? 0 : userStatsResolver.visibleFollowerCount(userId),
                hiddenByBlock ? 0 : userStatsResolver.visibleFollowingCount(userId),
                hiddenByBlock ? 0 : membershipCount(repository.groupMemberships(), userId),
                hiddenByBlock ? 0 : membershipCount(repository.communityMemberships(), userId),
                hiddenByBlock ? 0 : userStatsResolver.authoredContentCount(userId),
                hiddenByBlock ? 0 : userStatsResolver.publicContentCount(userId),
                hiddenByBlock ? 0 : userStatsResolver.visibleContentCount(viewerId, userId),
                context.visibility());
    }

    private FollowState viewerFollowState(String viewerId, String userId, boolean hiddenByBlock) {
        if (viewerId.equals(userId)) {
            return new FollowState("self", null);
        }
        if (hiddenByBlock) {
            return new FollowState("blocked", null);
        }
        SocialUserFollowRecord follow = repository.userFollow(viewerId, userId);
        if (follow != null) {
            return new FollowState("following", follow.createdAt());
        }
        SocialUserFollowRequestRecord request = repository.userFollowRequest(viewerId, userId);
        if (request != null && ("pending".equals(request.status()) || "rejected".equals(request.status()))) {
            return new FollowState(request.status(), request.updatedAt());
        }
        return new FollowState("none", null);
    }

    private int friendCount(String userId) {
        return (int) repository.friendships().stream()
                .filter(friendship -> friendship.firstUserId().equals(userId)
                        || friendship.secondUserId().equals(userId))
                .count();
    }

    private int membershipCount(Iterable<MembershipRecord> memberships, String userId) {
        int count = 0;
        for (MembershipRecord membership : memberships) {
            if (membership.memberId().equals(userId)) {
                count++;
            }
        }
        return count;
    }

    private record FollowState(String status, Instant updatedAt) {
    }
}
