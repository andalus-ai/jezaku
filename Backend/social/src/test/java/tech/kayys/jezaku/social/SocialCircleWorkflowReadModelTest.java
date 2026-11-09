package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleWorkflowReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T12:45:00Z");

    @Test
    void pagesTargetMembershipRequestsByTargetTypeRequestTypeAndStatus() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveCircleMembershipRequest(request(
                "request_old",
                "group_a",
                "group",
                "user_old",
                "join_request",
                "pending",
                10));
        repository.saveCircleMembershipRequest(request(
                "request_new",
                "group_a",
                "group",
                "user_new",
                "join_request",
                "pending",
                20));
        repository.saveCircleMembershipRequest(request(
                "request_wrong_type",
                "group_a",
                "group",
                "user_invited",
                "invite",
                "pending",
                30));
        repository.saveCircleMembershipRequest(request(
                "request_wrong_status",
                "group_a",
                "group",
                "user_done",
                "join_request",
                "approved",
                40));
        repository.saveCircleMembershipRequest(request(
                "request_wrong_target",
                "group_b",
                "group",
                "user_other",
                "join_request",
                "pending",
                50));
        SocialCircleWorkflowReadModel readModel = readModel(repository);

        SocialCircleWorkflowReadModel.WorkflowPage<CircleMembershipRequestRecord> firstPage =
                readModel.targetRequests("group_a", "group", "join_request", "pending", 1, "");
        SocialCircleWorkflowReadModel.WorkflowPage<CircleMembershipRequestRecord> secondPage =
                readModel.targetRequests(
                        "group_a",
                        "group",
                        "join_request",
                        "pending",
                        1,
                        firstPage.nextCursor());

        assertEquals(List.of("request_new"), requestIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("request_old"), requestIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    @Test
    void pagesUserCircleRequestsByUserRequestTypeAndStatus() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveCircleMembershipRequest(request(
                "invite_old",
                "group_a",
                "group",
                "user_a",
                "invite",
                "pending",
                10));
        repository.saveCircleMembershipRequest(request(
                "invite_new",
                "community_a",
                "community",
                "user_a",
                "invite",
                "pending",
                20));
        repository.saveCircleMembershipRequest(request(
                "join_skip",
                "group_b",
                "group",
                "user_a",
                "join_request",
                "pending",
                30));
        repository.saveCircleMembershipRequest(request(
                "user_skip",
                "group_c",
                "group",
                "user_b",
                "invite",
                "pending",
                40));
        SocialCircleWorkflowReadModel readModel = readModel(repository);

        SocialCircleWorkflowReadModel.WorkflowPage<CircleMembershipRequestRecord> page =
                readModel.userRequests("user_a", "invite", "pending", 10, "");

        assertEquals(List.of("invite_new", "invite_old"), requestIds(page));
        assertFalse(page.hasMore());
    }

    @Test
    void pagesContentModerationByTargetAndUpdatedAt() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveCircleContentModeration(moderation(
                "moderation_old",
                "group_a",
                "group",
                "removed",
                10,
                10));
        repository.saveCircleContentModeration(moderation(
                "moderation_new",
                "group_a",
                "group",
                "removed",
                20,
                30));
        repository.saveCircleContentModeration(moderation(
                "moderation_restored_skip",
                "group_a",
                "group",
                "restored",
                30,
                40));
        repository.saveCircleContentModeration(moderation(
                "moderation_target_skip",
                "group_b",
                "group",
                "removed",
                40,
                50));
        SocialCircleWorkflowReadModel readModel = readModel(repository);

        SocialCircleWorkflowReadModel.WorkflowPage<CircleContentModerationRecord> firstPage =
                readModel.contentModeration("group_a", "group", "removed", 1, "");
        SocialCircleWorkflowReadModel.WorkflowPage<CircleContentModerationRecord> secondPage =
                readModel.contentModeration("group_a", "group", "removed", 1, firstPage.nextCursor());

        assertEquals(List.of("moderation_new"), moderationIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("moderation_old"), moderationIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    private SocialCircleWorkflowReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialCircleMembershipPolicy membershipPolicy =
                new SocialCircleMembershipPolicy(repository, relationshipPolicy::blockedEitherWay);
        return new SocialCircleWorkflowReadModel(
                repository,
                new SocialChronologicalPaginationPlanner(),
                membershipPolicy);
    }

    private CircleMembershipRequestRecord request(
            String requestId,
            String targetId,
            String targetType,
            String userId,
            String requestType,
            String status,
            long createdSeconds) {
        return new CircleMembershipRequestRecord(
                requestId,
                targetId,
                targetType,
                userId,
                "actor_a",
                requestType,
                status,
                "",
                BASE_TIME.plusSeconds(createdSeconds),
                BASE_TIME.plusSeconds(createdSeconds));
    }

    private CircleContentModerationRecord moderation(
            String moderationId,
            String targetId,
            String targetType,
            String status,
            long createdSeconds,
            long updatedSeconds) {
        return new CircleContentModerationRecord(
                moderationId,
                moderationId + "_content",
                targetId,
                targetType,
                "actor_a",
                status,
                status,
                "",
                BASE_TIME.plusSeconds(createdSeconds),
                BASE_TIME.plusSeconds(updatedSeconds));
    }

    private List<String> requestIds(
            SocialCircleWorkflowReadModel.WorkflowPage<CircleMembershipRequestRecord> page) {
        return page.items().stream().map(CircleMembershipRequestRecord::requestId).toList();
    }

    private List<String> moderationIds(
            SocialCircleWorkflowReadModel.WorkflowPage<CircleContentModerationRecord> page) {
        return page.items().stream().map(CircleContentModerationRecord::moderationId).toList();
    }
}
