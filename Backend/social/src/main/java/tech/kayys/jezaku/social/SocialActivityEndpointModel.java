package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityMarkReadResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;

import java.util.Objects;
import java.util.Set;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialActivityEndpointModel {
    private static final Set<String> ACTIVITY_MODES = Set.of("inbox", "outbox", "all");

    private final SocialActivityReadModel readModel;
    private final SocialActivityWriteModel writeModel;
    private final int maxActivityLimit;

    SocialActivityEndpointModel(
            SocialActivityReadModel readModel,
            SocialActivityWriteModel writeModel,
            int maxActivityLimit) {
        this.readModel = Objects.requireNonNull(readModel, "readModel");
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.maxActivityLimit = maxActivityLimit;
    }

    SocialActivityListResponse activities(String userId, String mode, Integer limit, String cursor) {
        String user = requireText(userId, "userId");
        String normalizedMode = activityMode(mode);
        int normalizedLimit = normalizeBoundedInt(limit, 50, 1, maxActivityLimit, "limit");
        return readModel.list(user, normalizedMode, normalizedLimit, cursor);
    }

    SocialActivitySummaryResponse summary(String userId) {
        return readModel.summary(requireText(userId, "userId"));
    }

    SocialActivityResponse markRead(String activityId, String actorUserId) {
        SocialActivityRecord updated = writeModel.markRead(activityId, actorUserId);
        return readModel.response(updated, updated.recipientId());
    }

    SocialActivityMarkReadResponse markAllRead(String userId) {
        SocialActivityWriteModel.MarkReadAllResult result = writeModel.markInboxRead(userId);
        return new SocialActivityMarkReadResponse(
                result.userId(),
                result.markedReadCount(),
                result.unreadCount());
    }

    private String activityMode(String mode) {
        return optionalChoice(
                mode,
                "inbox",
                ACTIVITY_MODES,
                "mode",
                "mode must be inbox, outbox, or all");
    }
}
