package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;

import java.util.List;
import java.util.Objects;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialActivityWriteModel {
    private final SocialActivityGraphStore repository;

    SocialActivityWriteModel(SocialActivityGraphStore repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    SocialActivityRecord markRead(String activityId, String actorUserId) {
        String actor = requireText(actorUserId, "actorUserId");
        SocialActivityRecord activity = requireActivity(activityId);
        if (!activity.recipientId().equals(actor)) {
            throw new ForbiddenException("Only the activity recipient can mark it read");
        }
        SocialActivityRecord updated = activity.withRead(true);
        repository.saveActivity(updated);
        return updated;
    }

    MarkReadAllResult markInboxRead(String userId) {
        String user = requireText(userId, "userId");
        List<SocialActivityRecord> unreadInbox = repository.activities().stream()
                .filter(activity -> activity.recipientId().equals(user))
                .filter(activity -> !activity.read())
                .toList();
        unreadInbox.stream()
                .map(activity -> activity.withRead(true))
                .forEach(repository::saveActivity);
        return new MarkReadAllResult(user, unreadInbox.size(), 0);
    }

    private SocialActivityRecord requireActivity(String activityId) {
        String normalizedActivityId = requireText(activityId, "activityId");
        SocialActivityRecord activity = repository.activity(normalizedActivityId);
        if (activity == null) {
            throw new NotFoundException("Activity not found: " + normalizedActivityId);
        }
        return activity;
    }

    record MarkReadAllResult(String userId, int markedReadCount, int unreadCount) {
    }
}
