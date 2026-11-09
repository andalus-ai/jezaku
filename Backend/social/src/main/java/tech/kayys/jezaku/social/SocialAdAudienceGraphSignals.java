package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.function.BiFunction;
import java.util.function.Function;

final class SocialAdAudienceGraphSignals implements AdAudienceGraphSignals {
    private final BiFunction<String, String, SocialRelationshipContextResponse> relationshipContextResolver;
    private final SocialConnectionIndex connectionIndex;
    private final SocialCircleMembershipIndex circleMembershipIndex;
    private final SocialUserInterestIndex userInterestIndex;
    private final BiFunction<String, String, Integer> visibleContentCountResolver;
    private final Function<String, String> userLabelResolver;

    SocialAdAudienceGraphSignals(
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContextResolver,
            SocialConnectionIndex connectionIndex,
            SocialCircleMembershipIndex circleMembershipIndex,
            SocialUserInterestIndex userInterestIndex,
            BiFunction<String, String, Integer> visibleContentCountResolver,
            Function<String, String> userLabelResolver) {
        this.relationshipContextResolver = Objects.requireNonNull(
                relationshipContextResolver,
                "relationshipContextResolver");
        this.connectionIndex = Objects.requireNonNull(connectionIndex, "connectionIndex");
        this.circleMembershipIndex = Objects.requireNonNull(circleMembershipIndex, "circleMembershipIndex");
        this.userInterestIndex = Objects.requireNonNull(userInterestIndex, "userInterestIndex");
        this.visibleContentCountResolver = Objects.requireNonNull(
                visibleContentCountResolver,
                "visibleContentCountResolver");
        this.userLabelResolver = Objects.requireNonNull(userLabelResolver, "userLabelResolver");
    }

    @Override
    public SocialRelationshipContextResponse relationshipContext(String advertiserId, String candidateUserId) {
        return relationshipContextResolver.apply(advertiserId, candidateUserId);
    }

    @Override
    public boolean friendOfFriend(String advertiserId, String candidateUserId) {
        return connectionIndex.friendOfFriend(advertiserId, candidateUserId);
    }

    @Override
    public List<String> sharedGroupIds(String advertiserId, String candidateUserId) {
        return circleMembershipIndex.sharedGroupIds(advertiserId, candidateUserId);
    }

    @Override
    public List<String> sharedCommunityIds(String advertiserId, String candidateUserId) {
        return circleMembershipIndex.sharedCommunityIds(advertiserId, candidateUserId);
    }

    @Override
    public boolean candidateFollowsAdvertiser(String advertiserId, String candidateUserId) {
        return connectionIndex.candidateFollows(advertiserId, candidateUserId);
    }

    @Override
    public Set<String> userInterestTags(String userId) {
        return userInterestIndex.userInterestTags(userId);
    }

    @Override
    public Set<String> userGroupIds(String userId) {
        return circleMembershipIndex.groupIdsFor(userId);
    }

    @Override
    public Set<String> userCommunityIds(String userId) {
        return circleMembershipIndex.communityIdsFor(userId);
    }

    @Override
    public int visibleContentCount(String advertiserId, String candidateUserId) {
        return visibleContentCountResolver.apply(advertiserId, candidateUserId);
    }

    @Override
    public String userLabel(String userId) {
        return userLabelResolver.apply(userId);
    }
}
