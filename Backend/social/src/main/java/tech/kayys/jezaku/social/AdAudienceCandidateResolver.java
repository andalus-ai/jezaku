package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

final class AdAudienceCandidateResolver {
    private final AdAudienceGraphSignals graphSignals;

    AdAudienceCandidateResolver(AdAudienceGraphSignals graphSignals) {
        this.graphSignals = Objects.requireNonNull(graphSignals, "graphSignals");
    }

    SocialAdAudienceCandidate campaignCandidate(SocialAdCampaignRecord campaign, String viewerId) {
        SocialAdCampaignRecord resolvedCampaign = Objects.requireNonNull(campaign, "campaign");
        return candidate(
                resolvedCampaign.advertiserId(),
                viewerId,
                resolvedCampaign.maxDepth(),
                Set.copyOf(resolvedCampaign.relationScopes()),
                Set.copyOf(resolvedCampaign.targetTags()),
                Set.copyOf(resolvedCampaign.targetGroupIds()),
                Set.copyOf(resolvedCampaign.targetCommunityIds()));
    }

    SocialAdAudienceCandidate candidate(
            String advertiserId,
            String candidateUserId,
            int maxDepth,
            Set<String> relationScopes,
            Set<String> targetTags,
            Set<String> targetGroupIds,
            Set<String> targetCommunityIds) {
        SocialRelationshipContextResponse context = graphSignals.relationshipContext(advertiserId, candidateUserId);
        Set<String> relations = audienceRelations(advertiserId, candidateUserId, context);
        int depth = AdAudiencePlanner.audienceDepth(context.connectionDepth(), relations);
        if (depth > maxDepth || (!relationScopes.isEmpty() && relations.stream().noneMatch(relationScopes::contains))) {
            return null;
        }

        List<String> matchedTags = intersection(graphSignals.userInterestTags(candidateUserId), targetTags);
        List<String> matchedGroupIds = matchedTargetIds(
                targetGroupIds,
                graphSignals.sharedGroupIds(advertiserId, candidateUserId),
                graphSignals.userGroupIds(candidateUserId));
        List<String> matchedCommunityIds = matchedTargetIds(
                targetCommunityIds,
                graphSignals.sharedCommunityIds(advertiserId, candidateUserId),
                graphSignals.userCommunityIds(candidateUserId));

        if (!targetTags.isEmpty() && matchedTags.isEmpty()) {
            return null;
        }
        if (!targetGroupIds.isEmpty() && matchedGroupIds.isEmpty()) {
            return null;
        }
        if (!targetCommunityIds.isEmpty() && matchedCommunityIds.isEmpty()) {
            return null;
        }

        List<String> sortedRelations = AdAudiencePlanner.sortedRelations(relations);
        String primaryRelation = sortedRelations.getFirst();
        int visibleCount = graphSignals.visibleContentCount(advertiserId, candidateUserId);
        double relevanceScore = AdAudiencePlanner.relevanceScore(
                context.affinityScore(),
                primaryRelation,
                sortedRelations,
                matchedTags,
                matchedGroupIds,
                matchedCommunityIds,
                visibleCount);
        return new SocialAdAudienceCandidate(
                candidateUserId,
                graphSignals.userLabel(candidateUserId),
                primaryRelation,
                depth,
                context.affinityScore(),
                sortedRelations,
                matchedTags,
                matchedGroupIds,
                matchedCommunityIds,
                visibleCount,
                relevanceScore,
                AdAudiencePlanner.reasons(
                        primaryRelation,
                        sortedRelations,
                        matchedTags,
                        matchedGroupIds,
                        matchedCommunityIds,
                        visibleCount));
    }

    private Set<String> audienceRelations(
            String advertiserId,
            String candidateUserId,
            SocialRelationshipContextResponse context) {
        LinkedHashSet<String> relations = new LinkedHashSet<>();
        if (context.directFriend()) {
            relations.add(context.viewerMarkedCloseFriend() ? "close_friend" : "friend");
        }
        if (context.familyLink()) {
            relations.add("family");
        }
        if (graphSignals.friendOfFriend(advertiserId, candidateUserId)) {
            relations.add("friend_of_friend");
        }
        if (!graphSignals.sharedGroupIds(advertiserId, candidateUserId).isEmpty()) {
            relations.add("shared_group");
        }
        if (!graphSignals.sharedCommunityIds(advertiserId, candidateUserId).isEmpty()) {
            relations.add("shared_community");
        }
        if (graphSignals.candidateFollowsAdvertiser(advertiserId, candidateUserId)) {
            relations.add("follower");
        }
        if (relations.isEmpty()) {
            relations.add("public");
        }
        return Set.copyOf(relations);
    }

    private List<String> matchedTargetIds(
            Set<String> targetIds,
            List<String> sharedTargetIds,
            Set<String> userTargetIds) {
        return targetIds.isEmpty()
                ? sharedTargetIds
                : intersection(userTargetIds, targetIds);
    }

    private List<String> intersection(Set<String> candidateValues, Set<String> targetValues) {
        if (candidateValues.isEmpty() || targetValues.isEmpty()) {
            return List.of();
        }
        return candidateValues.stream()
                .filter(targetValues::contains)
                .sorted()
                .toList();
    }
}
