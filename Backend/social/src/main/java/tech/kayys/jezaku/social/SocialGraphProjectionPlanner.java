package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;

import java.util.Objects;
import java.util.function.Function;

final class SocialGraphProjectionPlanner {
    private final SocialNetworkProjectionReadModel networkProjectionReadModel;
    private final SocialConnectionPathReadModel connectionPathReadModel;
    private final SocialNeighborhoodReadModel neighborhoodReadModel;

    SocialGraphProjectionPlanner(SocialGraphRepository repository, Function<String, String> userLabel) {
        SocialGraphRepository normalizedRepository = Objects.requireNonNull(repository, "repository");
        Function<String, String> normalizedUserLabel = Objects.requireNonNull(userLabel, "userLabel");
        this.networkProjectionReadModel = new SocialNetworkProjectionReadModel(
                normalizedRepository,
                normalizedUserLabel);
        this.connectionPathReadModel = new SocialConnectionPathReadModel(
                normalizedRepository,
                normalizedUserLabel);
        this.neighborhoodReadModel = new SocialNeighborhoodReadModel(
                normalizedRepository,
                normalizedUserLabel);
    }

    SocialNetworkResponse network(String userId, int maxDepth) {
        return networkProjectionReadModel.network(userId, maxDepth);
    }

    SocialNeighborhoodSummaryResponse neighborhood(String userId, int maxDepth, int limit) {
        return neighborhoodReadModel.summary(userId, maxDepth, limit);
    }

    SocialConnectionPathResponse connectionPath(String fromUserId, String toUserId, int maxDepth) {
        return connectionPathReadModel.path(fromUserId, toUserId, maxDepth);
    }
}
