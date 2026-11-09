package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
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
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialCircleWriteModel {
    private static final Set<String> CIRCLE_JOIN_DECISIONS = Set.of("approve", "reject");
    private static final Set<String> CIRCLE_INVITE_DECISIONS = Set.of("accept", "decline");

    private final SocialCircleGraphStore repository;
    private final SocialCircleMembershipPolicy membershipPolicy;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final ActivityRecorder activityRecorder;
    private final Supplier<Instant> now;
    private final Supplier<String> groupIds;
    private final Supplier<String> communityIds;
    private final Supplier<String> joinRequestIds;
    private final Supplier<String> inviteIds;

    SocialCircleWriteModel(
            SocialCircleGraphStore repository,
            SocialCircleMembershipPolicy membershipPolicy,
            SocialRelationshipPolicy relationshipPolicy,
            ActivityRecorder activityRecorder) {
        this(
                repository,
                membershipPolicy,
                relationshipPolicy,
                activityRecorder,
                Instant::now,
                () -> "group_" + UUID.randomUUID(),
                () -> "community_" + UUID.randomUUID(),
                () -> "circle_request_" + UUID.randomUUID(),
                () -> "circle_invite_" + UUID.randomUUID());
    }

    SocialCircleWriteModel(
            SocialCircleGraphStore repository,
            SocialCircleMembershipPolicy membershipPolicy,
            SocialRelationshipPolicy relationshipPolicy,
            ActivityRecorder activityRecorder,
            Supplier<Instant> now,
            Supplier<String> groupIds,
            Supplier<String> communityIds,
            Supplier<String> joinRequestIds,
            Supplier<String> inviteIds) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.membershipPolicy = Objects.requireNonNull(membershipPolicy, "membershipPolicy");
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        this.activityRecorder = Objects.requireNonNull(activityRecorder, "activityRecorder");
        this.now = Objects.requireNonNull(now, "now");
        this.groupIds = Objects.requireNonNull(groupIds, "groupIds");
        this.communityIds = Objects.requireNonNull(communityIds, "communityIds");
        this.joinRequestIds = Objects.requireNonNull(joinRequestIds, "joinRequestIds");
        this.inviteIds = Objects.requireNonNull(inviteIds, "inviteIds");
    }

    SocialGroupRecord createGroup(SocialGroupCreateRequest request) {
        requireBody(request);
        String groupId = optionalTrim(request.groupId(), "");
        if (groupId.isEmpty()) {
            groupId = groupIds.get();
        }
        String ownerId = requireText(request.ownerId(), "ownerId");
        Instant createdAt = now.get();
        SocialGroupRecord group = new SocialGroupRecord(
                groupId,
                requireText(request.name(), "name"),
                visibility(request.visibility()),
                createdAt);
        repository.saveGroup(group);
        repository.saveGroupMembership(new MembershipRecord(ownerId, groupId, "owner", createdAt));
        return group;
    }

    SocialCommunityRecord createCommunity(SocialCommunityCreateRequest request) {
        requireBody(request);
        String communityId = optionalTrim(request.communityId(), "");
        if (communityId.isEmpty()) {
            communityId = communityIds.get();
        }
        String ownerId = requireText(request.ownerId(), "ownerId");
        Instant createdAt = now.get();
        SocialCommunityRecord community = new SocialCommunityRecord(
                communityId,
                requireText(request.name(), "name"),
                visibility(request.visibility()),
                createdAt);
        repository.saveCommunity(community);
        repository.saveCommunityMembership(new MembershipRecord(ownerId, communityId, "owner", createdAt));
        return community;
    }

    MembershipRecord addMember(
            String targetType,
            String targetId,
            MembershipCreateRequest request,
            String actorUserId) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String memberId = requireText(request.memberId(), "memberId");
        String role = membershipRole(request.role());
        String actor = optionalTrim(actorUserId, "");
        if (!actor.isEmpty()) {
            membershipPolicy.requireManager(actor, target.targetId(), target.targetType(), target.memberships());
            if ("owner".equals(role) || "admin".equals(role)) {
                membershipPolicy.requireOwner(actor, target.targetId(), target.targetType(), target.memberships());
            }
            relationshipPolicy.ensureNotBlocked(actor, memberId);
            membershipPolicy.ensureCandidateCanJoin(
                    memberId,
                    target.targetId(),
                    target.targetType(),
                    target.memberships());
        }
        MembershipRecord membership = new MembershipRecord(memberId, target.targetId(), role, now.get());
        saveMembership(target.targetType(), membership);
        return membership;
    }

    MembershipRecord join(String targetType, String targetId, MembershipJoinRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String user = requireText(request.userId(), "userId");
        MembershipRecord existing = membershipPolicy.membershipFor(target.memberships(), target.targetId(), user);
        if (existing != null) {
            return existing;
        }
        membershipPolicy.ensurePublicJoin(target.visibility(), target.targetType());
        membershipPolicy.ensureJoinNotBlocked(user, target.memberships(), target.targetId(), target.targetType());
        MembershipRecord membership = new MembershipRecord(user, target.targetId(), "member", now.get());
        saveMembership(target.targetType(), membership);
        return membership;
    }

    void leave(String targetType, String targetId, String userId) {
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String user = requireText(userId, "userId");
        MembershipRecord existing = membershipPolicy.membershipFor(target.memberships(), target.targetId(), user);
        if (existing != null) {
            membershipPolicy.ensureNotLastOwner(target.memberships(), existing, target.targetType());
            removeMembership(target.targetType(), user, target.targetId());
        }
    }

    void removeMember(
            String targetType,
            String targetId,
            String memberId,
            String actorUserId) {
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String normalizedMemberId = requireText(memberId, "memberId");
        MembershipRecord existing =
                membershipPolicy.membershipFor(target.memberships(), target.targetId(), normalizedMemberId);
        if (existing == null) {
            return;
        }
        String actor = optionalTrim(actorUserId, "");
        MembershipRecord actorMembership = null;
        if (!actor.isEmpty() && !actor.equals(normalizedMemberId)) {
            actorMembership = membershipPolicy.requireManager(
                    actor,
                    target.targetId(),
                    target.targetType(),
                    target.memberships());
        }
        membershipPolicy.ensureRemovalAllowed(actorMembership, existing);
        membershipPolicy.ensureNotLastOwner(target.memberships(), existing, target.targetType());
        removeMembership(target.targetType(), normalizedMemberId, target.targetId());
    }

    MembershipRecord updateMemberRole(
            String targetType,
            String targetId,
            String memberId,
            MembershipRoleUpdateRequest request,
            String actorUserId) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String normalizedMemberId = requireText(memberId, "memberId");
        String role = membershipRole(request.role());
        MembershipRecord existing = membershipPolicy.requireMembership(
                target.memberships(),
                target.targetId(),
                normalizedMemberId,
                target.targetType());
        String actor = optionalTrim(actorUserId, "");
        if (!actor.isEmpty()) {
            membershipPolicy.requireOwner(actor, target.targetId(), target.targetType(), target.memberships());
        }
        membershipPolicy.ensureRoleChangeAllowed(target.memberships(), existing, role, target.targetType());
        MembershipRecord updated = new MembershipRecord(
                existing.memberId(),
                existing.targetId(),
                role,
                existing.createdAt());
        saveMembership(target.targetType(), updated);
        return updated;
    }

    SocialCircleOwnershipTransferResult transferOwnership(
            String targetType,
            String targetId,
            CircleOwnershipTransferRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String actor = requireText(request.actorUserId(), "actorUserId");
        String newOwnerId = requireText(request.newOwnerId(), "newOwnerId");
        MembershipRecord actorMembership = membershipPolicy.requireOwner(
                actor,
                target.targetId(),
                target.targetType(),
                target.memberships());
        MembershipRecord newOwnerMembership = membershipPolicy.requireMembership(
                target.memberships(),
                target.targetId(),
                newOwnerId,
                target.targetType());
        relationshipPolicy.ensureNotBlocked(actor, newOwnerId);
        Instant transferredAt = now.get();
        saveMembership(target.targetType(), new MembershipRecord(
                newOwnerMembership.memberId(),
                newOwnerMembership.targetId(),
                "owner",
                newOwnerMembership.createdAt()));
        String previousOwnerRole = "owner";
        if (!actor.equals(newOwnerId)) {
            MembershipRecord previousOwner = new MembershipRecord(
                    actorMembership.memberId(),
                    actorMembership.targetId(),
                    "admin",
                    actorMembership.createdAt());
            saveMembership(target.targetType(), previousOwner);
            previousOwnerRole = previousOwner.role();
        }
        activityRecorder.record(
                "circle_ownership_transferred",
                actor,
                newOwnerId,
                "",
                "",
                "",
                target.name() + " ownership transferred");
        return new SocialCircleOwnershipTransferResult(
                target.targetId(),
                target.targetType(),
                actor,
                newOwnerId,
                previousOwnerRole,
                "owner",
                transferredAt);
    }

    CircleMembershipRequestRecord requestJoin(
            String targetType,
            String targetId,
            CircleMembershipRequestCreateRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String user = requireText(request.userId(), "userId");
        if ("public".equals(target.visibility())) {
            throw new ForbiddenException("Public " + target.targetType() + " circles can be joined directly");
        }
        if ("invite_only".equals(target.visibility())) {
            throw new ForbiddenException("Invite-only " + target.targetType() + " circles require an invitation");
        }
        membershipPolicy.ensureCandidateCanJoin(user, target.targetId(), target.targetType(), target.memberships());
        CircleMembershipRequestRecord existing = membershipPolicy.pendingRequest(
                target.targetType(),
                target.targetId(),
                user,
                "join_request");
        if (existing != null) {
            return existing;
        }
        Instant requestedAt = now.get();
        CircleMembershipRequestRecord created = new CircleMembershipRequestRecord(
                joinRequestIds.get(),
                target.targetId(),
                target.targetType(),
                user,
                user,
                "join_request",
                "pending",
                optionalTextMaxLength(request.message(), "", "message", 500),
                requestedAt,
                requestedAt);
        repository.saveCircleMembershipRequest(created);
        notifyManagers(target, user, "circle_join_requested", "Join request for " + target.name());
        return created;
    }

    CircleMembershipRequestRecord decideJoinRequest(
            String targetType,
            String targetId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        CircleMembershipRequestRecord existing = membershipPolicy.requireRequest(
                requestId,
                target.targetType(),
                target.targetId(),
                "join_request");
        membershipPolicy.requirePendingRequest(existing);
        String actor = requireText(request.actorUserId(), "actorUserId");
        membershipPolicy.requireManager(actor, target.targetId(), target.targetType(), target.memberships());
        String decision = optionalChoice(
                request.decision(),
                "",
                CIRCLE_JOIN_DECISIONS,
                "decision",
                "decision must be approve or reject");
        Instant decidedAt = now.get();
        String status = "approve".equals(decision) ? "approved" : "rejected";
        if ("approved".equals(status)) {
            membershipPolicy.ensureJoinNotBlocked(
                    existing.userId(),
                    target.memberships(),
                    target.targetId(),
                    target.targetType());
            if (!membershipPolicy.memberOf(target.memberships(), existing.userId(), target.targetId())) {
                saveMembership(target.targetType(), new MembershipRecord(
                        existing.userId(),
                        target.targetId(),
                        "member",
                        decidedAt));
            }
        }
        CircleMembershipRequestRecord updated = existing.withStatus(status, decidedAt);
        repository.saveCircleMembershipRequest(updated);
        activityRecorder.record(
                "circle_join_" + status,
                actor,
                existing.userId(),
                "",
                "",
                "",
                decisionMessage(request.message(), target, status));
        return updated;
    }

    CircleMembershipRequestRecord inviteMember(
            String targetType,
            String targetId,
            CircleMembershipInviteCreateRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        String inviter = requireText(request.inviterId(), "inviterId");
        String user = requireText(request.userId(), "userId");
        if (inviter.equals(user)) {
            throw new BadRequestException("Users cannot invite themselves");
        }
        membershipPolicy.requireManager(inviter, target.targetId(), target.targetType(), target.memberships());
        relationshipPolicy.ensureNotBlocked(inviter, user);
        membershipPolicy.ensureCandidateCanJoin(user, target.targetId(), target.targetType(), target.memberships());
        CircleMembershipRequestRecord existing = membershipPolicy.pendingRequest(
                target.targetType(),
                target.targetId(),
                user,
                "invite");
        if (existing != null) {
            return existing;
        }
        Instant invitedAt = now.get();
        CircleMembershipRequestRecord created = new CircleMembershipRequestRecord(
                inviteIds.get(),
                target.targetId(),
                target.targetType(),
                user,
                inviter,
                "invite",
                "pending",
                optionalTextMaxLength(request.message(), "", "message", 500),
                invitedAt,
                invitedAt);
        repository.saveCircleMembershipRequest(created);
        activityRecorder.record(
                "circle_invited",
                inviter,
                user,
                "",
                "",
                "",
                "Invitation to " + target.name());
        return created;
    }

    CircleMembershipRequestRecord decideInvite(
            String targetType,
            String targetId,
            String requestId,
            CircleMembershipDecisionRequest request) {
        requireBody(request);
        CircleTarget target = requireCircleTarget(targetType, targetId);
        CircleMembershipRequestRecord existing = membershipPolicy.requireRequest(
                requestId,
                target.targetType(),
                target.targetId(),
                "invite");
        membershipPolicy.requirePendingRequest(existing);
        String actor = requireText(request.actorUserId(), "actorUserId");
        if (!actor.equals(existing.userId())) {
            throw new ForbiddenException("Only the invited user can answer this invitation");
        }
        String decision = optionalChoice(
                request.decision(),
                "",
                CIRCLE_INVITE_DECISIONS,
                "decision",
                "decision must be accept or decline");
        Instant decidedAt = now.get();
        String status = "accept".equals(decision) ? "accepted" : "declined";
        if ("accepted".equals(status)) {
            membershipPolicy.ensureJoinNotBlocked(
                    existing.userId(),
                    target.memberships(),
                    target.targetId(),
                    target.targetType());
            if (!membershipPolicy.memberOf(target.memberships(), existing.userId(), target.targetId())) {
                saveMembership(target.targetType(), new MembershipRecord(
                        existing.userId(),
                        target.targetId(),
                        "member",
                        decidedAt));
            }
        }
        CircleMembershipRequestRecord updated = existing.withStatus(status, decidedAt);
        repository.saveCircleMembershipRequest(updated);
        activityRecorder.record(
                "circle_invite_" + status,
                actor,
                existing.actorUserId(),
                "",
                "",
                "",
                decisionMessage(request.message(), target, status));
        return updated;
    }

    private CircleTarget requireCircleTarget(String targetType, String targetId) {
        if ("group".equals(targetType)) {
            SocialGroupRecord group = requireGroup(targetId);
            return new CircleTarget(
                    group.groupId(),
                    "group",
                    group.name(),
                    group.visibility(),
                    repository.groupMemberships());
        }
        if ("community".equals(targetType)) {
            SocialCommunityRecord community = requireCommunity(targetId);
            return new CircleTarget(
                    community.communityId(),
                    "community",
                    community.name(),
                    community.visibility(),
                    repository.communityMemberships());
        }
        throw new BadRequestException("targetType must be group or community");
    }

    private SocialGroupRecord requireGroup(String groupId) {
        String normalizedGroupId = requireText(groupId, "groupId");
        SocialGroupRecord group = repository.group(normalizedGroupId);
        if (group == null) {
            throw new NotFoundException("Group not found: " + normalizedGroupId);
        }
        return group;
    }

    private SocialCommunityRecord requireCommunity(String communityId) {
        String normalizedCommunityId = requireText(communityId, "communityId");
        SocialCommunityRecord community = repository.community(normalizedCommunityId);
        if (community == null) {
            throw new NotFoundException("Community not found: " + normalizedCommunityId);
        }
        return community;
    }

    private void saveMembership(String targetType, MembershipRecord membership) {
        membershipPolicy.saveMembership(targetType, membership);
    }

    private void removeMembership(String targetType, String memberId, String targetId) {
        membershipPolicy.removeMembership(targetType, memberId, targetId);
    }

    private void notifyManagers(CircleTarget target, String actorId, String eventType, String message) {
        target.memberships().stream()
                .filter(membership -> membership.targetId().equals(target.targetId()))
                .filter(membership -> "owner".equals(membership.role()) || "admin".equals(membership.role()))
                .map(MembershipRecord::memberId)
                .distinct()
                .filter(managerId -> !actorId.equals(managerId))
                .forEach(managerId -> activityRecorder.record(
                        eventType,
                        actorId,
                        managerId,
                        "",
                        "",
                        "",
                        message));
    }

    private String decisionMessage(String message, CircleTarget target, String status) {
        String normalizedMessage = optionalTextMaxLength(message, "", "message", 500);
        if (!normalizedMessage.isEmpty()) {
            return normalizedMessage;
        }
        return target.name() + " membership " + status;
    }

    private String visibility(String visibility) {
        return optionalChoice(visibility, "public", Set.of("public", "private", "invite_only"),
                "visibility", "visibility must be public, private, or invite_only");
    }

    private String membershipRole(String role) {
        return optionalChoice(role, "member", Set.of("owner", "admin", "member"),
                "role", "role must be owner, admin, or member");
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }

    @FunctionalInterface
    interface ActivityRecorder {
        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String sourceType,
                String message);
    }

    private record CircleTarget(
            String targetId,
            String targetType,
            String name,
            String visibility,
            List<MembershipRecord> memberships) {
    }
}
