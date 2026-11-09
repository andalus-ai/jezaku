package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipInviteCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipJoinRequest;
import tech.kayys.jezaku.social.SocialDtos.MembershipRoleUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupCreateRequest;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SocialCircleWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T12:00:00Z");

    @Test
    void createsCirclesAndHandlesDirectPublicMemberships() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        ActivityLog activities = new ActivityLog();
        SocialCircleWriteModel writeModel = writeModel(repository, activities);

        SocialGroupRecord group = writeModel.createGroup(
                new SocialGroupCreateRequest("", "Creators", "public", "owner"));
        SocialCommunityRecord community = writeModel.createCommunity(
                new SocialCommunityCreateRequest("community_city", "City Lens", "private", "community_owner"));
        MembershipRecord membership = writeModel.join(
                "group",
                group.groupId(),
                new MembershipJoinRequest("member"));
        MembershipRecord existing = writeModel.join(
                "group",
                group.groupId(),
                new MembershipJoinRequest("member"));

        assertEquals("group_1", group.groupId());
        assertEquals("public", group.visibility());
        assertEquals("community_city", community.communityId());
        assertEquals("owner", membership(repository.groupMemberships(), "owner").memberId());
        assertEquals("community_owner", membership(repository.communityMemberships(), "community_owner").memberId());
        assertEquals("member", membership.memberId());
        assertEquals(membership, existing);

        writeModel.leave("group", group.groupId(), "member");

        assertFalse(repository.groupMemberships().stream()
                .anyMatch(record -> record.memberId().equals("member")));
        assertThrows(ForbiddenException.class, () -> writeModel.join(
                "community",
                community.communityId(),
                new MembershipJoinRequest("visitor")));
    }

    @Test
    void managesMemberRolesAndOwnershipTransfers() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        ActivityLog activities = new ActivityLog();
        SocialCircleWriteModel writeModel = writeModel(repository, activities);
        SocialGroupRecord group = writeModel.createGroup(
                new SocialGroupCreateRequest("group_creators", "Creators", "public", "owner"));
        writeModel.addMember(
                "group",
                group.groupId(),
                new MembershipCreateRequest("candidate", "member"),
                "owner");

        MembershipRecord admin = writeModel.updateMemberRole(
                "group",
                group.groupId(),
                "candidate",
                new MembershipRoleUpdateRequest("admin"),
                "owner");
        SocialCircleOwnershipTransferResult transfer = writeModel.transferOwnership(
                "group",
                group.groupId(),
                new CircleOwnershipTransferRequest("owner", "candidate"));

        assertEquals("admin", admin.role());
        assertEquals("group_creators", transfer.targetId());
        assertEquals("owner", transfer.previousOwnerId());
        assertEquals("candidate", transfer.newOwnerId());
        assertEquals("admin", transfer.previousOwnerRole());
        assertEquals("owner", membership(repository.groupMemberships(), "candidate").role());
        assertEquals("admin", membership(repository.groupMemberships(), "owner").role());
        assertEquals("circle_ownership_transferred", activities.records().getFirst().eventType());
        assertEquals("candidate", activities.records().getFirst().recipientUserId());
    }

    @Test
    void handlesPrivateJoinRequestsAndInvites() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        ActivityLog activities = new ActivityLog();
        SocialCircleWriteModel writeModel = writeModel(repository, activities);
        SocialGroupRecord privateGroup = writeModel.createGroup(
                new SocialGroupCreateRequest("group_private", "Private Creators", "private", "owner"));
        SocialCommunityRecord inviteOnlyCommunity = writeModel.createCommunity(
                new SocialCommunityCreateRequest("community_invite", "Invite City", "invite_only", "owner"));

        CircleMembershipRequestRecord joinRequest = writeModel.requestJoin(
                "group",
                privateGroup.groupId(),
                new CircleMembershipRequestCreateRequest("candidate", "please"));
        CircleMembershipRequestRecord duplicateJoinRequest = writeModel.requestJoin(
                "group",
                privateGroup.groupId(),
                new CircleMembershipRequestCreateRequest("candidate", "please again"));
        CircleMembershipRequestRecord approved = writeModel.decideJoinRequest(
                "group",
                privateGroup.groupId(),
                joinRequest.requestId(),
                new CircleMembershipDecisionRequest("owner", "approve", "welcome"));
        CircleMembershipRequestRecord invite = writeModel.inviteMember(
                "community",
                inviteOnlyCommunity.communityId(),
                new CircleMembershipInviteCreateRequest("owner", "guest", "come in"));
        CircleMembershipRequestRecord acceptedInvite = writeModel.decideInvite(
                "community",
                inviteOnlyCommunity.communityId(),
                invite.requestId(),
                new CircleMembershipDecisionRequest("guest", "accept", ""));

        assertEquals("circle_request_1", joinRequest.requestId());
        assertEquals(joinRequest, duplicateJoinRequest);
        assertEquals("approved", approved.status());
        assertEquals("member", membership(repository.groupMemberships(), "candidate").role());
        assertEquals("circle_invite_1", invite.requestId());
        assertEquals("accepted", acceptedInvite.status());
        assertEquals("member", membership(repository.communityMemberships(), "guest").role());
        assertEquals("circle_join_requested", activities.records().get(0).eventType());
        assertEquals("circle_join_approved", activities.records().get(1).eventType());
        assertEquals("welcome", activities.records().get(1).message());
        assertEquals("circle_invited", activities.records().get(2).eventType());
        assertEquals("circle_invite_accepted", activities.records().get(3).eventType());
    }

    private static SocialCircleWriteModel writeModel(
            InMemorySocialGraphRepository repository,
            ActivityLog activities) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialCircleMembershipPolicy membershipPolicy =
                new SocialCircleMembershipPolicy(repository, relationshipPolicy::blockedEitherWay);
        return new SocialCircleWriteModel(
                repository,
                membershipPolicy,
                relationshipPolicy,
                activities::record,
                sequenceTime(),
                sequence("group_"),
                sequence("community_"),
                sequence("circle_request_"),
                sequence("circle_invite_"));
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
            records.add(new ActivityRecord(eventType, actorUserId, recipientUserId, message));
        }

        List<ActivityRecord> records() {
            return records;
        }
    }

    private record ActivityRecord(
            String eventType,
            String actorUserId,
            String recipientUserId,
            String message) {
    }
}
