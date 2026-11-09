package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodBucket;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.BiFunction;

final class SocialAudiencePreviewReadModel {
    private final SocialGraphRepository repository;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialGraphTraversalIndex traversalIndex;
    private final SocialCircleMembershipIndex circleMembershipIndex;
    private final BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext;

    SocialAudiencePreviewReadModel(
            SocialGraphRepository repository,
            SocialRelationshipPolicy relationshipPolicy,
            SocialCircleMembershipIndex circleMembershipIndex,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext) {
        this.repository = repository;
        this.relationshipPolicy = relationshipPolicy;
        this.traversalIndex = new SocialGraphTraversalIndex(repository, relationshipPolicy);
        this.circleMembershipIndex = circleMembershipIndex;
        this.relationshipContext = relationshipContext;
    }

    SocialAudiencePreviewResponse preview(String ownerId, String scope, String targetId, int limit) {
        if ("public".equals(scope)) {
            return new SocialAudiencePreviewResponse(
                    ownerId,
                    scope,
                    "",
                    false,
                    0,
                    0,
                    traversalIndex.blockedHiddenCount(ownerId),
                    limit,
                    List.of(),
                    List.of());
        }
        if ("private".equals(scope)) {
            return response(ownerId, scope, "", true, Set.of(), limit);
        }

        return switch (scope) {
            case "friends" -> response(
                    ownerId,
                    scope,
                    "",
                    true,
                    candidates(traversalIndex.friendConnections(ownerId).stream()
                            .map(FriendConnection::userId)
                            .toList()),
                    limit);
            case "close_friends" -> response(
                    ownerId,
                    scope,
                    "",
                    true,
                    candidates(repository.closeFriends().stream()
                            .filter(closeFriend -> closeFriend.ownerId().equals(ownerId))
                            .map(CloseFriendRecord::friendId)
                            .filter(friendId -> relationshipPolicy.friends(ownerId, friendId))
                            .toList()),
                    limit);
            case "family" -> response(
                    ownerId,
                    scope,
                    "",
                    true,
                    candidates(traversalIndex.familyFor(ownerId).stream()
                            .map(FamilyConnection::relativeId)
                            .toList()),
                    limit);
            case "group" -> response(
                    ownerId,
                    scope,
                    targetId,
                    true,
                    candidates(circleMembershipIndex.groupMemberIdsExcept(ownerId, targetId)),
                    limit);
            case "community" -> response(
                    ownerId,
                    scope,
                    targetId,
                    true,
                    candidates(circleMembershipIndex.communityMemberIdsExcept(ownerId, targetId)),
                    limit);
            default -> throw new IllegalArgumentException("Unsupported audience scope: " + scope);
        };
    }

    private SocialAudiencePreviewResponse response(
            String ownerId,
            String scope,
            String targetId,
            boolean enumerable,
            Set<String> candidateUserIds,
            int limit) {
        Set<String> included = new HashSet<>(candidateUserIds);
        included.remove(ownerId);
        int beforeBlockFilter = included.size();
        included.removeIf(candidate -> relationshipPolicy.blockedEitherWay(ownerId, candidate));
        List<String> includedUserIds = included.stream()
                .sorted()
                .limit(limit)
                .toList();
        return new SocialAudiencePreviewResponse(
                ownerId,
                scope,
                targetId,
                enumerable,
                included.size(),
                includedUserIds.size(),
                beforeBlockFilter - included.size(),
                limit,
                includedUserIds,
                audienceBuckets(ownerId, included));
    }

    private Set<String> candidates(List<String> userIds) {
        return new HashSet<>(userIds);
    }

    private List<SocialNeighborhoodBucket> audienceBuckets(String ownerId, Set<String> includedUserIds) {
        Set<String> closeFriendIds = new HashSet<>();
        Set<String> friendIds = new HashSet<>();
        Set<String> familyIds = new HashSet<>();
        Set<String> connectedIds = new HashSet<>();
        Set<String> publicIds = new HashSet<>();
        for (String userId : includedUserIds) {
            SocialRelationshipContextResponse context = relationshipContext.apply(ownerId, userId);
            if (context.viewerMarkedCloseFriend()) {
                closeFriendIds.add(userId);
            } else {
                switch (context.relation()) {
                    case "friend" -> friendIds.add(userId);
                    case "family" -> familyIds.add(userId);
                    case "connected" -> connectedIds.add(userId);
                    default -> publicIds.add(userId);
                }
            }
        }
        return List.of(
                neighborhoodBucket("close_friend", closeFriendIds),
                neighborhoodBucket("friend", friendIds),
                neighborhoodBucket("family", familyIds),
                neighborhoodBucket("connected", connectedIds),
                neighborhoodBucket("public", publicIds));
    }

    private SocialNeighborhoodBucket neighborhoodBucket(String relation, Set<String> userIds) {
        List<String> sortedUserIds = userIds.stream().sorted().toList();
        return new SocialNeighborhoodBucket(relation, sortedUserIds.size(), sortedUserIds);
    }
}
