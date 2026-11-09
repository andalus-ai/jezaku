package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityTypeSummary;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.function.BiFunction;

final class SocialActivityReadModel {
    private final SocialActivityGraphStore repository;
    private final SocialChronologicalPaginationPlanner chronologicalPaginationPlanner;
    private final BiFunction<String, String, SocialUserProfileCardResponse> userCard;

    SocialActivityReadModel(
            SocialActivityGraphStore repository,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            BiFunction<String, String, SocialUserProfileCardResponse> userCard) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.chronologicalPaginationPlanner = Objects.requireNonNull(
                chronologicalPaginationPlanner,
                "chronologicalPaginationPlanner");
        this.userCard = Objects.requireNonNull(userCard, "userCard");
    }

    SocialActivityListResponse list(String userId, String mode, int limit, String cursor) {
        List<SocialActivityRecord> matchingActivities = repository.activities().stream()
                .filter(activity -> matchesMode(activity, userId, mode))
                .toList();
        List<SocialChronologicalPaginationPlanner.Candidate<SocialActivityRecord>> candidates =
                matchingActivities.stream()
                        .map(activity -> new SocialChronologicalPaginationPlanner.Candidate<>(
                                activity,
                                activity.createdAt(),
                                activity.activityId()))
                        .toList();
        SocialChronologicalPaginationPlanner.Page<SocialActivityRecord> page =
                chronologicalPaginationPlanner.descending(limit, cursor, candidates);
        List<SocialActivityResponse> activities = page.items().stream()
                .map(activity -> response(activity, userId))
                .toList();
        return new SocialActivityListResponse(
                userId,
                mode,
                activities.size(),
                unreadInboxCount(matchingActivities, userId),
                limit,
                page.hasMore(),
                page.nextCursor(),
                activities);
    }

    SocialActivitySummaryResponse summary(String userId) {
        List<SocialActivityRecord> inbox = repository.activities().stream()
                .filter(activity -> activity.recipientId().equals(userId))
                .toList();
        List<SocialActivityTypeSummary> eventTypes = inbox.stream()
                .map(SocialActivityRecord::eventType)
                .distinct()
                .sorted()
                .map(eventType -> typeSummary(inbox, eventType))
                .toList();
        Instant latestUnreadAt = inbox.stream()
                .filter(activity -> !activity.read())
                .map(SocialActivityRecord::createdAt)
                .max(Comparator.naturalOrder())
                .orElse(null);
        return new SocialActivitySummaryResponse(
                userId,
                inbox.size(),
                unreadInboxCount(inbox, userId),
                latestUnreadAt,
                eventTypes);
    }

    SocialActivityResponse response(SocialActivityRecord activity, String viewerId) {
        return new SocialActivityResponse(
                activity.activityId(),
                activity.eventType(),
                activity.actorId(),
                userCard.apply(activity.actorId(), viewerId),
                activity.recipientId(),
                userCard.apply(activity.recipientId(), viewerId),
                activity.contentId(),
                activity.commentId(),
                activity.reactionType(),
                activity.message(),
                activity.createdAt(),
                activity.read());
    }

    boolean matchesMode(SocialActivityRecord activity, String userId, String mode) {
        return switch (mode) {
            case "inbox" -> activity.recipientId().equals(userId);
            case "outbox" -> activity.actorId().equals(userId);
            default -> activity.recipientId().equals(userId) || activity.actorId().equals(userId);
        };
    }

    private SocialActivityTypeSummary typeSummary(List<SocialActivityRecord> activities, String eventType) {
        int count = (int) activities.stream()
                .filter(activity -> activity.eventType().equals(eventType))
                .count();
        int unreadCount = (int) activities.stream()
                .filter(activity -> activity.eventType().equals(eventType))
                .filter(activity -> !activity.read())
                .count();
        return new SocialActivityTypeSummary(eventType, count, unreadCount);
    }

    private int unreadInboxCount(List<SocialActivityRecord> activities, String userId) {
        return (int) activities.stream()
                .filter(activity -> !activity.read())
                .filter(activity -> activity.recipientId().equals(userId))
                .count();
    }
}
