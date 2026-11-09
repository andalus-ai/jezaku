package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;

import java.util.List;
import java.util.Objects;
import java.util.function.BiFunction;
import java.util.function.BiPredicate;

final class SocialUserStatsResolver {
    private final SocialGraphRepository repository;
    private final BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision;
    private final BiPredicate<String, String> contentHidden;
    private final BiPredicate<String, String> blockedEitherWay;

    SocialUserStatsResolver(
            SocialGraphRepository repository,
            BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> audienceDecision,
            BiPredicate<String, String> contentHidden,
            BiPredicate<String, String> blockedEitherWay) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.audienceDecision = Objects.requireNonNull(audienceDecision, "audienceDecision");
        this.contentHidden = Objects.requireNonNull(contentHidden, "contentHidden");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
    }

    int visibleContentCount(String viewerId, String ownerId) {
        return visibleContentForOwner(ownerId, viewerId).size();
    }

    List<SocialContentRecord> visibleContentForOwner(String ownerId, String viewerId) {
        return repository.contents().stream()
                .filter(content -> content.ownerId().equals(ownerId))
                .filter(content -> audienceDecision.apply(content, viewerId).canView())
                .filter(content -> !contentHidden.test(content.contentId(), viewerId))
                .toList();
    }

    int authoredContentCount(String ownerId) {
        return (int) repository.contents().stream()
                .filter(content -> content.ownerId().equals(ownerId))
                .count();
    }

    int publicContentCount(String ownerId) {
        return (int) repository.contents().stream()
                .filter(content -> content.ownerId().equals(ownerId))
                .filter(content -> "public".equals(content.scope()))
                .count();
    }

    int visibleFollowerCount(String userId) {
        return (int) repository.followers(userId).stream()
                .map(SocialUserFollowRecord::followerId)
                .filter(followerId -> !blockedEitherWay.test(userId, followerId))
                .count();
    }

    int visibleFollowingCount(String userId) {
        return (int) repository.following(userId).stream()
                .map(SocialUserFollowRecord::followedUserId)
                .filter(followedUserId -> !blockedEitherWay.test(userId, followedUserId))
                .count();
    }
}
