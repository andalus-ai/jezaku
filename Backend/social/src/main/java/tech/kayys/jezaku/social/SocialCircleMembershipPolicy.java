package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;

import java.util.List;
import java.util.Objects;
import java.util.function.BiPredicate;

import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialCircleMembershipPolicy {
    private final SocialCircleGraphStore repository;
    private final BiPredicate<String, String> blockedEitherWay;

    SocialCircleMembershipPolicy(
            SocialCircleGraphStore repository,
            BiPredicate<String, String> blockedEitherWay) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.blockedEitherWay = Objects.requireNonNull(blockedEitherWay, "blockedEitherWay");
    }

    boolean memberOf(List<MembershipRecord> memberships, String memberId, String targetId) {
        return membershipFor(memberships, targetId, memberId) != null;
    }

    MembershipRecord membershipFor(List<MembershipRecord> memberships, String targetId, String memberId) {
        return memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .filter(membership -> membership.memberId().equals(memberId))
                .findFirst()
                .orElse(null);
    }

    MembershipRecord requireMembership(
            List<MembershipRecord> memberships,
            String targetId,
            String memberId,
            String targetType) {
        MembershipRecord membership = membershipFor(memberships, targetId, memberId);
        if (membership == null) {
            throw new NotFoundException(targetType + " membership not found: " + memberId + " in " + targetId);
        }
        return membership;
    }

    MembershipRecord requireManager(
            String actorUserId,
            String targetId,
            String targetType,
            List<MembershipRecord> memberships) {
        MembershipRecord manager = memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .filter(membership -> membership.memberId().equals(actorUserId))
                .filter(membership -> "owner".equals(membership.role()) || "admin".equals(membership.role()))
                .findFirst()
                .orElse(null);
        if (manager == null) {
            throw new ForbiddenException("Only " + targetType + " owners and admins can manage this circle");
        }
        return manager;
    }

    MembershipRecord requireOwner(
            String actorUserId,
            String targetId,
            String targetType,
            List<MembershipRecord> memberships) {
        MembershipRecord owner = memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .filter(membership -> membership.memberId().equals(actorUserId))
                .filter(membership -> "owner".equals(membership.role()))
                .findFirst()
                .orElse(null);
        if (owner == null) {
            throw new ForbiddenException("Only " + targetType + " owners can change roles or transfer ownership");
        }
        return owner;
    }

    void ensureRemovalAllowed(MembershipRecord actorMembership, MembershipRecord removedMembership) {
        if (actorMembership != null
                && "admin".equals(actorMembership.role())
                && !"member".equals(removedMembership.role())) {
            throw new ForbiddenException("Admins can only remove regular members");
        }
    }

    void ensureRoleChangeAllowed(
            List<MembershipRecord> memberships,
            MembershipRecord existing,
            String requestedRole,
            String targetType) {
        if ("owner".equals(existing.role()) && !"owner".equals(requestedRole)) {
            ensureNotLastOwner(memberships, existing, targetType);
        }
    }

    void ensurePublicJoin(String visibility, String targetType) {
        if (!"public".equals(visibility)) {
            throw new ForbiddenException("Only public " + targetType + " circles can be joined directly");
        }
    }

    void ensureCandidateCanJoin(
            String userId,
            String targetId,
            String targetType,
            List<MembershipRecord> memberships) {
        if (memberOf(memberships, userId, targetId)) {
            throw conflict("User is already a member of this " + targetType);
        }
        ensureJoinNotBlocked(userId, memberships, targetId, targetType);
    }

    void ensureJoinNotBlocked(
            String userId,
            List<MembershipRecord> memberships,
            String targetId,
            String targetType) {
        if (joinBlockedByOwner(userId, memberships, targetId)) {
            throw conflict("User cannot join because they are blocked by an owner of this " + targetType);
        }
    }

    boolean joinBlockedByOwner(String userId, List<MembershipRecord> memberships, String targetId) {
        return memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .filter(membership -> "owner".equals(membership.role()))
                .map(MembershipRecord::memberId)
                .anyMatch(ownerId -> blockedEitherWay.test(userId, ownerId));
    }

    boolean canLeave(MembershipRecord membership, List<MembershipRecord> memberships) {
        return !"owner".equals(membership.role()) || ownerCount(memberships, membership.targetId()) > 1;
    }

    void ensureNotLastOwner(
            List<MembershipRecord> memberships,
            MembershipRecord membership,
            String targetType) {
        if ("owner".equals(membership.role()) && ownerCount(memberships, membership.targetId()) <= 1) {
            throw conflict("Cannot remove or demote the last owner of this " + targetType);
        }
    }

    ViewerState viewerState(
            String targetType,
            String targetId,
            String visibility,
            List<MembershipRecord> memberships,
            String viewerId) {
        String viewer = optionalTrim(viewerId, "");
        if (viewer.isEmpty()) {
            return new ViewerState("", false, false, false, false, false, false, false);
        }
        MembershipRecord membership = membershipFor(memberships, targetId, viewer);
        boolean member = membership != null;
        boolean pendingJoinRequest = !member && pendingRequest(
                targetType,
                targetId,
                viewer,
                "join_request") != null;
        boolean pendingInvite = !member && pendingRequest(
                targetType,
                targetId,
                viewer,
                "invite") != null;
        boolean blocked = joinBlockedByOwner(viewer, memberships, targetId);
        boolean availableCandidate = !member && !pendingJoinRequest && !pendingInvite && !blocked;
        return new ViewerState(
                member ? membership.role() : "",
                member,
                pendingJoinRequest,
                pendingInvite,
                blocked,
                availableCandidate && "public".equals(visibility),
                availableCandidate && "private".equals(visibility),
                member && canLeave(membership, memberships));
    }

    CircleMembershipRequestRecord pendingRequest(
            String targetType,
            String targetId,
            String userId,
            String requestType) {
        return repository.circleMembershipRequests().stream()
                .filter(request -> request.targetType().equals(targetType))
                .filter(request -> request.targetId().equals(targetId))
                .filter(request -> request.userId().equals(userId))
                .filter(request -> request.requestType().equals(requestType))
                .filter(request -> "pending".equals(request.status()))
                .findFirst()
                .orElse(null);
    }

    CircleMembershipRequestRecord requireRequest(
            String requestId,
            String targetType,
            String targetId,
            String requestType) {
        String normalizedRequestId = requireText(requestId, "requestId");
        CircleMembershipRequestRecord request = repository.circleMembershipRequest(normalizedRequestId);
        if (request == null
                || !request.targetType().equals(targetType)
                || !request.targetId().equals(targetId)
                || !request.requestType().equals(requestType)) {
            throw new NotFoundException("Circle membership request not found: " + normalizedRequestId);
        }
        return request;
    }

    void requirePendingRequest(CircleMembershipRequestRecord request) {
        if (!"pending".equals(request.status())) {
            throw conflict("Circle membership request is already " + request.status());
        }
    }

    boolean requestMatchesStatus(CircleMembershipRequestRecord request, String status) {
        return "all".equals(status) || request.status().equals(status);
    }

    void saveMembership(String targetType, MembershipRecord membership) {
        if ("group".equals(targetType)) {
            repository.saveGroupMembership(membership);
        } else if ("community".equals(targetType)) {
            repository.saveCommunityMembership(membership);
        } else {
            throw new BadRequestException("targetType must be group or community");
        }
    }

    void removeMembership(String targetType, String memberId, String targetId) {
        if ("group".equals(targetType)) {
            repository.removeGroupMembership(memberId, targetId);
        } else if ("community".equals(targetType)) {
            repository.removeCommunityMembership(memberId, targetId);
        } else {
            throw new BadRequestException("targetType must be group or community");
        }
    }

    private long ownerCount(List<MembershipRecord> memberships, String targetId) {
        return memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .filter(membership -> "owner".equals(membership.role()))
                .count();
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }

    record ViewerState(
            String role,
            boolean member,
            boolean pendingJoinRequest,
            boolean pendingInvite,
            boolean blocked,
            boolean canJoin,
            boolean canRequestJoin,
            boolean canLeave) {
    }
}
