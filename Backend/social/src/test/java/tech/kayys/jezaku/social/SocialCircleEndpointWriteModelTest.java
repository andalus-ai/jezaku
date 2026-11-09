package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipInviteCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipJoinRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipRoleUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class SocialCircleEndpointWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T08:00:00Z");

    @Test
    void hydratesGroupMembershipAndModerationWrites() {
        EndpointFixture fixture = fixture();
        SocialCircleEndpointWriteModel model = fixture.model();

        SocialGroupResponse group = model.createGroup(
                new SocialGroupCreateRequest("", "Camera Walkers", "public", "owner_a"));
        MembershipResponse admin = model.addGroupMember(
                group.groupId(),
                new MembershipCreateRequest("admin_a", "admin"),
                "owner_a");
        MembershipResponse member = model.joinGroup(
                group.groupId(),
                new MembershipJoinRequest("member_a"));
        fixture.repository().saveContent(new SocialContentRecord(
                "content_a",
                "member_a",
                "post",
                "group",
                group.groupId(),
                "Perimeter photo",
                BASE_TIME.plusSeconds(20)));

        CircleContentModerationResponse moderation = model.moderateGroupContent(
                group.groupId(),
                "content_a",
                new CircleContentModerationRequest("admin_a", "remove", "off topic"));
        MembershipResponse updatedAdmin = model.updateGroupMemberRole(
                group.groupId(),
                "admin_a",
                new MembershipRoleUpdateRequest("member"),
                "owner_a");
        model.removeGroupMember(group.groupId(), "member_a", "owner_a");

        assertEquals("group_1", group.groupId());
        assertEquals("Camera Walkers", group.name());
        assertEquals(1, group.memberCount());
        assertFalse(group.viewerMember());
        assertEquals("admin_a", admin.memberId());
        assertEquals("group", admin.targetType());
        assertEquals("admin", admin.role());
        assertEquals("member_a", member.memberId());
        assertEquals("member", member.role());
        assertEquals("circle_moderation_1", moderation.moderationId());
        assertEquals("removed", moderation.status());
        assertEquals("group", moderation.targetType());
        assertEquals("off topic", moderation.reason());
        assertEquals("member", updatedAdmin.role());
        assertFalse(fixture.repository().groupMemberships().stream()
                .anyMatch(membership -> membership.memberId().equals("member_a")));
        assertEquals("circle_content_removed", fixture.activities().records().getFirst().eventType());
        assertEquals("member_a", fixture.activities().records().getFirst().recipientUserId());
    }

    @Test
    void hydratesCommunityJoinInviteOwnershipAndLeaveWrites() {
        EndpointFixture fixture = fixture();
        SocialCircleEndpointWriteModel model = fixture.model();

        SocialCommunityResponse community = model.createCommunity(
                new SocialCommunityCreateRequest("", "Bandung Creators", "private", "owner_c"));
        CircleMembershipRequestResponse joinRequest = model.requestCommunityJoin(
                community.communityId(),
                new CircleMembershipRequestCreateRequest("candidate_c", "please"));
        CircleMembershipRequestResponse approved = model.decideCommunityJoinRequest(
                community.communityId(),
                joinRequest.requestId(),
                new CircleMembershipDecisionRequest("owner_c", "approve", "welcome"));
        CircleMembershipRequestResponse invite = model.inviteCommunityMember(
                community.communityId(),
                new CircleMembershipInviteCreateRequest("owner_c", "guest_c", "join us"));
        CircleMembershipRequestResponse accepted = model.decideCommunityInvite(
                community.communityId(),
                invite.requestId(),
                new CircleMembershipDecisionRequest("guest_c", "accept", ""));
        assertEquals("member", membership(fixture.repository().communityMemberships(), "candidate_c").role());

        CircleOwnershipTransferResponse transfer = model.transferCommunityOwnership(
                community.communityId(),
                new CircleOwnershipTransferRequest("owner_c", "candidate_c"));
        model.leaveCommunity(community.communityId(), "guest_c");

        assertEquals("community_1", community.communityId());
        assertEquals("private", community.visibility());
        assertEquals(1, community.memberCount());
        assertEquals("circle_request_1", joinRequest.requestId());
        assertEquals("community", joinRequest.targetType());
        assertEquals("join_request", joinRequest.requestType());
        assertEquals("pending", joinRequest.status());
        assertEquals("approved", approved.status());
        assertEquals("circle_invite_1", invite.requestId());
        assertEquals("pending", invite.status());
        assertEquals("accepted", accepted.status());
        assertEquals("guest_c", accepted.userId());
        assertEquals("community", transfer.targetType());
        assertEquals("owner_c", transfer.previousOwnerId());
        assertEquals("candidate_c", transfer.newOwnerId());
        assertEquals("admin", transfer.previousOwnerRole());
        assertEquals("owner", membership(fixture.repository().communityMemberships(), "candidate_c").role());
        assertEquals("admin", membership(fixture.repository().communityMemberships(), "owner_c").role());
        assertFalse(fixture.repository().communityMemberships().stream()
                .anyMatch(membership -> membership.memberId().equals("guest_c")));
    }

    private static EndpointFixture fixture() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        ActivityLog activities = new ActivityLog();
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialCircleMembershipPolicy membershipPolicy =
                new SocialCircleMembershipPolicy(repository, relationshipPolicy::blockedEitherWay);
        Supplier<Instant> now = sequenceTime();
        SocialCircleWriteModel writeModel = new SocialCircleWriteModel(
                repository,
                membershipPolicy,
                relationshipPolicy,
                activities::record,
                now,
                sequence("group_"),
                sequence("community_"),
                sequence("circle_request_"),
                sequence("circle_invite_"));
        SocialCircleContentModerationWriteModel moderationWriteModel = new SocialCircleContentModerationWriteModel(
                repository,
                membershipPolicy,
                activities::record,
                now,
                sequence("circle_moderation_"));
        SocialCirclePresentationResolver presentationResolver =
                new SocialCirclePresentationResolver(repository, membershipPolicy);
        return new EndpointFixture(
                repository,
                new SocialCircleEndpointWriteModel(writeModel, moderationWriteModel, presentationResolver),
                activities);
    }

    private static MembershipRecord membership(List<MembershipRecord> memberships, String memberId) {
        return memberships.stream()
                .filter(membership -> membership.memberId().equals(memberId))
                .findFirst()
                .orElseThrow();
    }

    private static Supplier<Instant> sequenceTime() {
        AtomicInteger counter = new AtomicInteger();
        return () -> BASE_TIME.plusSeconds(counter.getAndIncrement());
    }

    private static Supplier<String> sequence(String prefix) {
        AtomicInteger counter = new AtomicInteger();
        return () -> prefix + counter.incrementAndGet();
    }

    private record EndpointFixture(
            InMemorySocialGraphRepository repository,
            SocialCircleEndpointWriteModel model,
            ActivityLog activities) {
    }

    private static final class ActivityLog {
        private final List<ActivityRecord> records = new ArrayList<>();

        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String sourceType,
                String message) {
            records.add(new ActivityRecord(eventType, actorUserId, recipientUserId, contentId, message));
        }

        List<ActivityRecord> records() {
            return records;
        }
    }

    private record ActivityRecord(
            String eventType,
            String actorUserId,
            String recipientUserId,
            String contentId,
            String message) {
    }
}
