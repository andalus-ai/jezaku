package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphRepositoryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.util.Objects;
import java.util.function.Function;

/**
 * Coordinates social graph endpoint workflows, relationship context reads, and visibility decisions.
 */
final class SocialGraphCoordinator {
    private static final int DEFAULT_NETWORK_MAX_DEPTH = 3;
    private static final int DEFAULT_NEIGHBORHOOD_MAX_DEPTH = 3;
    private static final int DEFAULT_NEIGHBORHOOD_LIMIT = 25;
    private static final int DEFAULT_CONNECTION_PATH_MAX_DEPTH = 4;
    private static final int DEFAULT_RELATIONSHIP_CONTEXT_BATCH_SIZE = 100;

    private final SocialGraphEndpointReadModel endpointReadModel;
    private final SocialRelationshipContextReadModel relationshipContextReadModel;
    private final SocialVisibilityReadModel visibilityReadModel;

    SocialGraphCoordinator(
            SocialGraphRepository repository,
            SocialRelationshipPolicy relationshipPolicy,
            SocialCircleMembershipIndex circleMembershipIndex,
            Function<String, String> userLabel,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialRelationshipPolicy resolvedRelationshipPolicy =
                Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        SocialCircleMembershipIndex resolvedCircleMembershipIndex =
                Objects.requireNonNull(circleMembershipIndex, "circleMembershipIndex");
        Function<String, String> resolvedUserLabel = Objects.requireNonNull(userLabel, "userLabel");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        this.visibilityReadModel = new SocialVisibilityReadModel(resolvedRelationshipPolicy);
        this.relationshipContextReadModel = new SocialRelationshipContextReadModel(
                resolvedRepository,
                resolvedRelationshipPolicy,
                resolvedCircleMembershipIndex,
                new SocialRelationshipContextResolver(),
                visibilityReadModel::decisionFor,
                resolvedLimits.relationshipContextBatchSize());
        this.endpointReadModel = new SocialGraphEndpointReadModel(
                resolvedRepository,
                new SocialGraphSummaryReadModel(resolvedRepository, resolvedRelationshipPolicy),
                new SocialGraphProjectionPlanner(resolvedRepository, resolvedUserLabel),
                new SocialGraphEndpointReadModel.Limits(
                        resolvedLimits.networkMaxDepth(),
                        resolvedLimits.neighborhoodMaxDepth(),
                        resolvedLimits.neighborhoodLimit(),
                        resolvedLimits.connectionPathMaxDepth()));
    }

    SocialGraphResponse graph(String userId) {
        return endpointReadModel.graph(userId);
    }

    SocialNetworkResponse network(String userId, Integer maxDepth) {
        return endpointReadModel.network(userId, maxDepth);
    }

    SocialNeighborhoodSummaryResponse neighborhood(String userId, Integer maxDepth, Integer limit) {
        return endpointReadModel.neighborhood(userId, maxDepth, limit);
    }

    SocialConnectionPathResponse connectionPath(String fromUserId, String toUserId, Integer maxDepth) {
        return endpointReadModel.connectionPath(fromUserId, toUserId, maxDepth);
    }

    SocialGraphRepositoryResponse repositoryStatus() {
        return endpointReadModel.repositoryStatus();
    }

    SocialRelationshipContextResponse relationshipContext(String viewerId, String ownerId) {
        return relationshipContextReadModel.context(viewerId, ownerId);
    }

    SocialRelationshipContextBatchResponse relationshipContexts(SocialRelationshipContextBatchRequest request) {
        return relationshipContextReadModel.contexts(request);
    }

    SocialRelationshipContextResponse contextFor(String viewerId, String ownerId) {
        return relationshipContextReadModel.contextFor(viewerId, ownerId);
    }

    VisibilityDecision visibility(String viewerId, String ownerId) {
        return visibilityReadModel.visibility(viewerId, ownerId);
    }

    static Limits defaultLimits() {
        return new Limits(
                DEFAULT_NETWORK_MAX_DEPTH,
                DEFAULT_NEIGHBORHOOD_MAX_DEPTH,
                DEFAULT_NEIGHBORHOOD_LIMIT,
                DEFAULT_CONNECTION_PATH_MAX_DEPTH,
                DEFAULT_RELATIONSHIP_CONTEXT_BATCH_SIZE);
    }

    /**
     * Defines graph traversal and relationship context limits for graph endpoint orchestration.
     */
    record Limits(
            int networkMaxDepth,
            int neighborhoodMaxDepth,
            int neighborhoodLimit,
            int connectionPathMaxDepth,
            int relationshipContextBatchSize) {
    }
}
