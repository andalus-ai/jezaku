package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationCirclePreview;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationItem;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.util.List;
import java.util.Objects;
import java.util.function.BiFunction;
import java.util.function.Function;

final class SocialRecommendationReadModel {
    private final SocialGraphRepository repository;
    private final SocialRecommendationPlanner recommendationPlanner;
    private final SocialRecommendationPaginationPlanner paginationPlanner;
    private final Function<String, String> userLabel;
    private final BiFunction<String, String, SocialUserProfileCardResponse> userCard;
    private final int previewLimit;

    SocialRecommendationReadModel(
            SocialGraphRepository repository,
            SocialRecommendationPlanner recommendationPlanner,
            SocialRecommendationPaginationPlanner paginationPlanner,
            Function<String, String> userLabel,
            BiFunction<String, String, SocialUserProfileCardResponse> userCard,
            int previewLimit) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.recommendationPlanner = Objects.requireNonNull(recommendationPlanner, "recommendationPlanner");
        this.paginationPlanner = Objects.requireNonNull(paginationPlanner, "paginationPlanner");
        this.userLabel = Objects.requireNonNull(userLabel, "userLabel");
        this.userCard = Objects.requireNonNull(userCard, "userCard");
        this.previewLimit = previewLimit;
    }

    SocialRecommendationsResponse recommendations(String userId, int limit, String cursor) {
        SocialRecommendationPaginationPlanner.Page page =
                paginationPlanner.page(limit, cursor, recommendationPlanner.recommendations(userId));
        List<SocialRecommendationItem> recommendations = page.candidates().stream()
                .map(candidate -> recommendation(userId, candidate))
                .toList();

        return new SocialRecommendationsResponse(
                userId,
                recommendations.size(),
                limit,
                page.hasMore(),
                page.nextCursor(),
                recommendations);
    }

    private SocialRecommendationItem recommendation(
            String viewerId,
            SocialRecommendationPlanner.Candidate candidate) {
        return new SocialRecommendationItem(
                candidate.userId(),
                userLabel.apply(candidate.userId()),
                userCard.apply(candidate.userId(), viewerId),
                candidate.reason(),
                candidate.mutualFriendCount(),
                candidate.followedByFriendCount(),
                candidate.sharedGroupCount(),
                candidate.sharedCommunityCount(),
                candidate.familyLink(),
                candidate.followsViewer(),
                candidate.score(),
                candidate.mutualFriendIds(),
                candidate.followedByFriendIds(),
                candidate.sharedGroupIds(),
                candidate.sharedCommunityIds(),
                candidate.mutualFriendIds().stream()
                        .limit(previewLimit)
                        .map(mutualFriendId -> userCard.apply(mutualFriendId, viewerId))
                        .toList(),
                candidate.followedByFriendIds().stream()
                        .limit(previewLimit)
                        .map(friendId -> userCard.apply(friendId, viewerId))
                        .toList(),
                candidate.sharedGroupIds().stream()
                        .limit(previewLimit)
                        .map(this::groupPreview)
                        .toList(),
                candidate.sharedCommunityIds().stream()
                        .limit(previewLimit)
                        .map(this::communityPreview)
                        .toList());
    }

    private SocialRecommendationCirclePreview groupPreview(String groupId) {
        SocialGroupRecord group = repository.group(groupId);
        return new SocialRecommendationCirclePreview(
                groupId,
                "group",
                group == null ? groupId : group.name(),
                group == null ? "" : group.visibility());
    }

    private SocialRecommendationCirclePreview communityPreview(String communityId) {
        SocialCommunityRecord community = repository.community(communityId);
        return new SocialRecommendationCirclePreview(
                communityId,
                "community",
                community == null ? communityId : community.name(),
                community == null ? "" : community.visibility());
    }
}
