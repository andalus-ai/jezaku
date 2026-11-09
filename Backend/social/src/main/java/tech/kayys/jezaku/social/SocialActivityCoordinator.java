package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityMarkReadResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.util.Objects;
import java.util.function.BiFunction;

/**
 * Coordinates activity endpoint workflows for inbox/outbox reads, summaries, and read-state updates.
 */
final class SocialActivityCoordinator {
    private static final int DEFAULT_ACTIVITY_LIMIT = 100;

    private final SocialActivityEndpointModel endpointModel;

    SocialActivityCoordinator(
            SocialActivityGraphStore repository,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            BiFunction<String, String, SocialUserProfileCardResponse> userCard,
            Limits limits) {
        SocialActivityGraphStore resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialChronologicalPaginationPlanner resolvedChronologicalPaginationPlanner =
                Objects.requireNonNull(chronologicalPaginationPlanner, "chronologicalPaginationPlanner");
        BiFunction<String, String, SocialUserProfileCardResponse> resolvedUserCard =
                Objects.requireNonNull(userCard, "userCard");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        SocialActivityReadModel readModel = new SocialActivityReadModel(
                resolvedRepository,
                resolvedChronologicalPaginationPlanner,
                resolvedUserCard);
        SocialActivityWriteModel writeModel = new SocialActivityWriteModel(resolvedRepository);
        this.endpointModel = new SocialActivityEndpointModel(
                readModel,
                writeModel,
                resolvedLimits.activityLimit());
    }

    SocialActivityListResponse activities(String userId, String mode, Integer limit, String cursor) {
        return endpointModel.activities(userId, mode, limit, cursor);
    }

    SocialActivitySummaryResponse summary(String userId) {
        return endpointModel.summary(userId);
    }

    SocialActivityResponse markRead(String activityId, String actorUserId) {
        return endpointModel.markRead(activityId, actorUserId);
    }

    SocialActivityMarkReadResponse markAllRead(String userId) {
        return endpointModel.markAllRead(userId);
    }

    static Limits defaultLimits() {
        return new Limits(DEFAULT_ACTIVITY_LIMIT);
    }

    /**
     * Defines endpoint limits for activity list pagination.
     */
    record Limits(int activityLimit) {
    }
}
