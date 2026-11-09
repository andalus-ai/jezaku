package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphRepositoryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;

import java.util.Objects;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialGraphEndpointReadModel {
    private final SocialGraphRepository repository;
    private final SocialGraphSummaryReadModel graphSummaryReadModel;
    private final SocialGraphProjectionPlanner graphProjectionPlanner;
    private final Limits limits;

    SocialGraphEndpointReadModel(
            SocialGraphRepository repository,
            SocialGraphSummaryReadModel graphSummaryReadModel,
            SocialGraphProjectionPlanner graphProjectionPlanner,
            Limits limits) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.graphSummaryReadModel = Objects.requireNonNull(graphSummaryReadModel, "graphSummaryReadModel");
        this.graphProjectionPlanner = Objects.requireNonNull(graphProjectionPlanner, "graphProjectionPlanner");
        this.limits = Objects.requireNonNull(limits, "limits");
    }

    SocialGraphResponse graph(String userId) {
        return graphSummaryReadModel.summary(requireText(userId, "userId"));
    }

    SocialNetworkResponse network(String userId, Integer maxDepth) {
        String user = requireText(userId, "userId");
        int depth = normalizeBoundedInt(maxDepth, 2, 1, limits.networkMaxDepth(), "maxDepth");
        return graphProjectionPlanner.network(user, depth);
    }

    SocialNeighborhoodSummaryResponse neighborhood(String userId, Integer maxDepth, Integer limit) {
        String user = requireText(userId, "userId");
        int depth = normalizeBoundedInt(maxDepth, 2, 1, limits.neighborhoodMaxDepth(), "maxDepth");
        int normalizedLimit = normalizeBoundedInt(limit, 10, 1, limits.neighborhoodLimit(), "limit");
        return graphProjectionPlanner.neighborhood(user, depth, normalizedLimit);
    }

    SocialConnectionPathResponse connectionPath(String fromUserId, String toUserId, Integer maxDepth) {
        String from = requireText(fromUserId, "fromUserId");
        String to = requireText(toUserId, "toUserId");
        int depth = normalizeBoundedInt(maxDepth, 3, 1, limits.connectionPathMaxDepth(), "maxDepth");
        return graphProjectionPlanner.connectionPath(from, to, depth);
    }

    SocialGraphRepositoryResponse repositoryStatus() {
        SocialGraphRepositoryStatus status = repository.status();
        return new SocialGraphRepositoryResponse(
                status.backend(),
                status.ready(),
                status.database(),
                status.schemaBootstrapEnabled(),
                status.detail());
    }

    record Limits(int networkMaxDepth, int neighborhoodMaxDepth, int neighborhoodLimit, int connectionPathMaxDepth) {
    }
}
