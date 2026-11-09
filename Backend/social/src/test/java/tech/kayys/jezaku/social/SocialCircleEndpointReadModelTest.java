package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCircleContentListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileCardResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleEndpointReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-07T07:00:00Z");

    @Test
    void assemblesDirectoriesMembershipsAndContent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_camera", "Camera Club", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_private", "Camera Private", "private", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_camera", "Camera City", "invite_only", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_camera", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_camera", "member", BASE_TIME.plusSeconds(1)));
        repository.saveCommunityMembership(new MembershipRecord(
                "member_a",
                "community_camera",
                "member",
                BASE_TIME.plusSeconds(2)));
        repository.saveContent(content("content_old", "group", "group_camera", 10));
        repository.saveContent(content("content_new", "group", "group_camera", 20));
        SocialCircleEndpointReadModel readModel = readModel(repository);

        SocialGroupListResponse groups = readModel.groups(null, "", "#camera", "public", "owner_a");
        SocialCommunityListResponse communities = readModel.communities(null, "", "@camera", "invite_only", "member_a");
        MembershipListResponse groupMembers = readModel.groupMembers("group_camera", 1, "");
        MembershipListResponse userCommunities = readModel.userCommunities("member_a", null, "");
        SocialCircleContentListResponse firstContentPage =
                readModel.groupContent("group_camera", "owner_a", 1, "");

        assertEquals(List.of("group_camera"), groups.groups().stream().map(group -> group.groupId()).toList());
        assertEquals("owner", groups.groups().get(0).viewerRole());
        assertEquals(List.of("community_camera"), communities.communities().stream()
                .map(community -> community.communityId())
                .toList());
        assertEquals("member", communities.communities().get(0).viewerRole());
        assertEquals("group_camera", groupMembers.targetId());
        assertEquals("group", groupMembers.targetType());
        assertEquals(List.of("member_a"), groupMembers.memberships().stream()
                .map(membership -> membership.memberId())
                .toList());
        assertTrue(groupMembers.hasMore());
        assertEquals("member_a", userCommunities.userId());
        assertEquals(List.of("community_camera"), userCommunities.memberships().stream()
                .map(membership -> membership.targetId())
                .toList());
        assertEquals("Camera Club", firstContentPage.name());
        assertTrue(firstContentPage.viewerMember());
        assertEquals(List.of("content_new:owner_a"), firstContentPage.items().stream()
                .map(SocialContentResponse::caption)
                .toList());
        assertTrue(firstContentPage.hasMore());
    }

    @Test
    void assemblesCircleWorkflowListsAndRequiresManagers() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_camera", "Camera Club", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_camera", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_camera", "member", BASE_TIME));
        repository.saveCircleMembershipRequest(request("request_old", "user_old", "join_request", "pending", 10));
        repository.saveCircleMembershipRequest(request("request_new", "user_new", "join_request", "pending", 20));
        repository.saveCircleMembershipRequest(request("request_invite", "user_invited", "invite", "accepted", 30));
        repository.saveCircleContentModeration(moderation("moderation_old", "removed", 10, 10));
        repository.saveCircleContentModeration(moderation("moderation_new", "removed", 20, 30));
        repository.saveCircleContentModeration(moderation("moderation_restored", "restored", 30, 40));
        SocialCircleEndpointReadModel readModel = readModel(repository);

        CircleMembershipRequestListResponse joinRequests =
                readModel.groupJoinRequests("group_camera", "owner_a", null, 1, "");
        CircleMembershipRequestListResponse userInvites =
                readModel.userCircleInvites("user_invited", "all", null, "");
        CircleContentModerationListResponse moderation =
                readModel.groupContentModeration("group_camera", "owner_a", null, 1, "");

        assertEquals("pending", joinRequests.status());
        assertEquals(List.of("request_new"), joinRequests.requests().stream()
                .map(request -> request.requestId())
                .toList());
        assertTrue(joinRequests.hasMore());
        assertEquals("all", userInvites.status());
        assertEquals(List.of("request_invite"), userInvites.requests().stream()
                .map(request -> request.requestId())
                .toList());
        assertEquals("removed", moderation.status());
        assertEquals(List.of("moderation_new"), moderation.records().stream()
                .map(record -> record.moderationId())
                .toList());
        assertTrue(moderation.hasMore());
        assertThrows(ForbiddenException.class, () ->
                readModel.groupJoinRequests("group_camera", "member_a", null, null, ""));
    }

    @Test
    void rejectsInvalidDirectoryAndWorkflowFilters() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_camera", "Camera Club", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_camera", "owner", BASE_TIME));
        SocialCircleEndpointReadModel readModel = readModel(repository);

        assertThrows(BadRequestException.class, () -> readModel.groups(null, "", "", "secret", ""));
        assertThrows(BadRequestException.class, () ->
                readModel.groupJoinRequests("group_camera", "owner_a", "archived", null, ""));
        assertThrows(BadRequestException.class, () ->
                readModel.groupContentModeration("group_camera", "owner_a", "hidden", null, ""));
    }

    private SocialCircleEndpointReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialCircleMembershipPolicy membershipPolicy =
                new SocialCircleMembershipPolicy(repository, relationshipPolicy::blockedEitherWay);
        SocialCircleReadModel circleReadModel = new SocialCircleReadModel(
                repository,
                new SocialCircleDirectoryPaginationPlanner(),
                new SocialMembershipPaginationPlanner(),
                new SocialContentPaginationPlanner(),
                membershipPolicy,
                (content, viewerId) -> true);
        SocialCircleWorkflowReadModel workflowReadModel = new SocialCircleWorkflowReadModel(
                repository,
                new SocialChronologicalPaginationPlanner(),
                membershipPolicy);
        return new SocialCircleEndpointReadModel(
                repository,
                circleReadModel,
                workflowReadModel,
                membershipPolicy,
                new SocialCirclePresentationResolver(repository, membershipPolicy),
                SocialCircleEndpointReadModelTest::contentResponse,
                new SocialCircleEndpointReadModel.Limits(100, 100, 100, 100, 100));
    }

    private static SocialContentResponse contentResponse(SocialContentRecord content, String viewerId) {
        return new SocialContentResponse(
                content.contentId(),
                content.ownerId(),
                new SocialUserProfileCardResponse(content.ownerId(), content.ownerId(), content.ownerId(), "", "public", true),
                content.contentType(),
                content.scope(),
                content.targetId(),
                content.contentId() + ":" + viewerId,
                content.createdAt(),
                0,
                0,
                0,
                0,
                false,
                false,
                false,
                List.of(),
                null);
    }

    private SocialContentRecord content(String contentId, String scope, String targetId, long seconds) {
        return new SocialContentRecord(
                contentId,
                "owner_a",
                "post",
                scope,
                targetId,
                contentId,
                BASE_TIME.plusSeconds(seconds));
    }

    private CircleMembershipRequestRecord request(
            String requestId,
            String userId,
            String requestType,
            String status,
            long seconds) {
        return new CircleMembershipRequestRecord(
                requestId,
                "group_camera",
                "group",
                userId,
                "actor_a",
                requestType,
                status,
                "",
                BASE_TIME.plusSeconds(seconds),
                BASE_TIME.plusSeconds(seconds));
    }

    private CircleContentModerationRecord moderation(
            String moderationId,
            String status,
            long createdSeconds,
            long updatedSeconds) {
        return new CircleContentModerationRecord(
                moderationId,
                moderationId + "_content",
                "group_camera",
                "group",
                "owner_a",
                status,
                status,
                "",
                BASE_TIME.plusSeconds(createdSeconds),
                BASE_TIME.plusSeconds(updatedSeconds));
    }
}
