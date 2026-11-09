package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.List;

final class SocialCircleWorkflowReadModel {
    private final SocialCircleGraphStore repository;
    private final SocialChronologicalPaginationPlanner chronologicalPaginationPlanner;
    private final SocialCircleMembershipPolicy membershipPolicy;

    SocialCircleWorkflowReadModel(
            SocialCircleGraphStore repository,
            SocialChronologicalPaginationPlanner chronologicalPaginationPlanner,
            SocialCircleMembershipPolicy membershipPolicy) {
        this.repository = repository;
        this.chronologicalPaginationPlanner = chronologicalPaginationPlanner;
        this.membershipPolicy = membershipPolicy;
    }

    WorkflowPage<CircleMembershipRequestRecord> targetRequests(
            String targetId,
            String targetType,
            String requestType,
            String status,
            int limit,
            String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<CircleMembershipRequestRecord>> candidates =
                repository.circleMembershipRequests().stream()
                        .filter(request -> request.targetType().equals(targetType))
                        .filter(request -> request.targetId().equals(targetId))
                        .filter(request -> request.requestType().equals(requestType))
                        .filter(request -> membershipPolicy.requestMatchesStatus(request, status))
                        .map(request -> candidate(request, request.createdAt(), request.requestId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    WorkflowPage<CircleMembershipRequestRecord> userRequests(
            String userId,
            String requestType,
            String status,
            int limit,
            String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<CircleMembershipRequestRecord>> candidates =
                repository.circleMembershipRequests().stream()
                        .filter(request -> request.userId().equals(userId))
                        .filter(request -> request.requestType().equals(requestType))
                        .filter(request -> membershipPolicy.requestMatchesStatus(request, status))
                        .map(request -> candidate(request, request.createdAt(), request.requestId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    WorkflowPage<CircleContentModerationRecord> contentModeration(
            String targetId,
            String targetType,
            String status,
            int limit,
            String cursor) {
        List<SocialChronologicalPaginationPlanner.Candidate<CircleContentModerationRecord>> candidates =
                repository.circleContentModerations().stream()
                        .filter(moderation -> moderation.targetType().equals(targetType))
                        .filter(moderation -> moderation.targetId().equals(targetId))
                        .filter(moderation -> "all".equals(status) || moderation.status().equals(status))
                        .map(moderation -> candidate(
                                moderation,
                                moderation.updatedAt(),
                                moderation.moderationId()))
                        .toList();
        return descending(limit, cursor, candidates);
    }

    private <T> WorkflowPage<T> descending(
            int limit,
            String cursor,
            List<SocialChronologicalPaginationPlanner.Candidate<T>> candidates) {
        SocialChronologicalPaginationPlanner.Page<T> page =
                chronologicalPaginationPlanner.descending(limit, cursor, candidates);
        return new WorkflowPage<>(page.items(), page.hasMore(), page.nextCursor());
    }

    private <T> SocialChronologicalPaginationPlanner.Candidate<T> candidate(
            T item,
            Instant createdAt,
            String id) {
        return new SocialChronologicalPaginationPlanner.Candidate<>(item, createdAt, id);
    }

    record WorkflowPage<T>(List<T> items, boolean hasMore, String nextCursor) {
    }
}
