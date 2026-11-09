package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.util.List;
import java.util.Objects;
import java.util.function.BiFunction;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialRelationshipContextReadModel {
    private final SocialGraphRepository repository;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final SocialGraphTraversalIndex traversalIndex;
    private final SocialCircleMembershipIndex circleMembershipIndex;
    private final SocialRelationshipContextResolver relationshipContextResolver;
    private final BiFunction<String, String, VisibilityDecision> visibilityDecision;
    private final int maxBatchSize;

    SocialRelationshipContextReadModel(
            SocialGraphRepository repository,
            SocialRelationshipPolicy relationshipPolicy,
            SocialCircleMembershipIndex circleMembershipIndex,
            SocialRelationshipContextResolver relationshipContextResolver,
            BiFunction<String, String, VisibilityDecision> visibilityDecision,
            int maxBatchSize) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        this.traversalIndex = new SocialGraphTraversalIndex(repository, relationshipPolicy);
        this.circleMembershipIndex = Objects.requireNonNull(circleMembershipIndex, "circleMembershipIndex");
        this.relationshipContextResolver = Objects.requireNonNull(
                relationshipContextResolver,
                "relationshipContextResolver");
        this.visibilityDecision = Objects.requireNonNull(visibilityDecision, "visibilityDecision");
        this.maxBatchSize = maxBatchSize;
    }

    SocialRelationshipContextResponse context(String viewerId, String ownerId) {
        String viewer = requireText(viewerId, "viewerId");
        String owner = requireText(ownerId, "ownerId");
        return contextFor(viewer, owner);
    }

    SocialRelationshipContextBatchResponse contexts(SocialRelationshipContextBatchRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String viewer = requireText(request.viewerId(), "viewerId");
        List<SocialRelationshipContextResponse> contexts = SocialBatchIds.normalize(
                        request.ownerIds(),
                        "ownerIds",
                        maxBatchSize,
                        "users").stream()
                .map(ownerId -> contextFor(viewer, ownerId))
                .toList();
        return new SocialRelationshipContextBatchResponse(viewer, contexts.size(), contexts);
    }

    SocialRelationshipContextResponse contextFor(String viewerId, String ownerId) {
        boolean blocked = relationshipPolicy.blockedEitherWay(viewerId, ownerId);
        boolean directFriend = relationshipPolicy.friends(viewerId, ownerId);
        boolean viewerMarkedCloseFriend = relationshipPolicy.closeFriend(viewerId, ownerId);
        boolean ownerMarkedCloseFriend = relationshipPolicy.closeFriend(ownerId, viewerId);
        FamilyConnection family = traversalIndex.familyConnectionBetween(viewerId, ownerId);
        FriendRequestRecord pending = relationshipPolicy.pendingFriendRequestBetween(viewerId, ownerId);
        List<String> mutualFriendIds = blocked ? List.of() : traversalIndex.mutualFriendIds(viewerId, ownerId);
        List<String> sharedGroupIds = blocked ? List.of() : circleMembershipIndex.sharedGroupIds(viewerId, ownerId);
        List<String> sharedCommunityIds = blocked
                ? List.of()
                : circleMembershipIndex.sharedCommunityIds(viewerId, ownerId);
        VisibilityDecision visibility = visibilityDecision.apply(viewerId, ownerId);

        return relationshipContextResolver.resolve(new SocialRelationshipContextResolver.Signals(
                viewerId,
                ownerId,
                blocked,
                directFriend,
                viewerMarkedCloseFriend,
                ownerMarkedCloseFriend,
                family != null,
                family == null ? "" : family.relationship(),
                pendingDirection(viewerId, pending),
                mutualFriendIds,
                sharedGroupIds,
                sharedCommunityIds), visibility);
    }

    private String pendingDirection(String viewerId, FriendRequestRecord pending) {
        if (pending == null) {
            return "";
        }
        return pending.fromUserId().equals(viewerId) ? "pending_outgoing" : "pending_incoming";
    }
}
