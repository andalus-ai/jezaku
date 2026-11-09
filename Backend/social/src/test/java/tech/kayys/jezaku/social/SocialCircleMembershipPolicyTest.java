package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleMembershipPolicyTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T08:00:00Z");

    @Test
    void resolvesManagersOwnersAndViewerState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialCircleMembershipPolicy policy = new SocialCircleMembershipPolicy(repository, (first, second) -> false);
        List<MembershipRecord> memberships = List.of(
                membership("owner", "group_a", "owner"),
                membership("admin", "group_a", "admin"),
                membership("member", "group_a", "member"));
        repository.saveCircleMembershipRequest(circleRequest(
                "join_request",
                "group_a",
                "pending_user",
                "pending_user",
                "join_request",
                "pending"));
        repository.saveCircleMembershipRequest(circleRequest(
                "invite_request",
                "group_a",
                "invited_user",
                "owner",
                "invite",
                "pending"));

        assertEquals("owner", policy.requireManager("owner", "group_a", "group", memberships).role());
        assertEquals("admin", policy.requireManager("admin", "group_a", "group", memberships).role());
        assertEquals("owner", policy.requireOwner("owner", "group_a", "group", memberships).role());
        assertThrows(ForbiddenException.class, () ->
                policy.requireManager("member", "group_a", "group", memberships));
        assertThrows(ForbiddenException.class, () ->
                policy.requireOwner("admin", "group_a", "group", memberships));

        SocialCircleMembershipPolicy.ViewerState memberState =
                policy.viewerState("group", "group_a", "public", memberships, "member");
        SocialCircleMembershipPolicy.ViewerState joinState =
                policy.viewerState("group", "group_a", "public", memberships, "pending_user");
        SocialCircleMembershipPolicy.ViewerState inviteState =
                policy.viewerState("group", "group_a", "public", memberships, "invited_user");
        SocialCircleMembershipPolicy.ViewerState publicCandidate =
                policy.viewerState("group", "group_a", "public", memberships, "visitor");
        SocialCircleMembershipPolicy.ViewerState privateCandidate =
                policy.viewerState("group", "group_a", "private", memberships, "private_visitor");

        assertTrue(memberState.member());
        assertEquals("member", memberState.role());
        assertTrue(memberState.canLeave());
        assertTrue(joinState.pendingJoinRequest());
        assertFalse(joinState.canJoin());
        assertTrue(inviteState.pendingInvite());
        assertFalse(inviteState.canJoin());
        assertTrue(publicCandidate.canJoin());
        assertFalse(publicCandidate.canRequestJoin());
        assertFalse(privateCandidate.canJoin());
        assertTrue(privateCandidate.canRequestJoin());
    }

    @Test
    void protectsCircleRoleAndOwnershipBoundaries() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialCircleMembershipPolicy policy = new SocialCircleMembershipPolicy(repository, (first, second) -> false);
        MembershipRecord owner = membership("owner", "group_a", "owner");
        MembershipRecord secondOwner = membership("second_owner", "group_a", "owner");
        MembershipRecord admin = membership("admin", "group_a", "admin");
        MembershipRecord member = membership("member", "group_a", "member");
        List<MembershipRecord> soloOwnerMemberships = List.of(owner, admin, member);
        List<MembershipRecord> multiOwnerMemberships = List.of(owner, secondOwner, admin, member);

        assertThrows(WebApplicationException.class, () ->
                policy.ensureNotLastOwner(soloOwnerMemberships, owner, "group"));
        assertThrows(WebApplicationException.class, () ->
                policy.ensureRoleChangeAllowed(soloOwnerMemberships, owner, "admin", "group"));
        policy.ensureNotLastOwner(multiOwnerMemberships, owner, "group");
        policy.ensureRoleChangeAllowed(multiOwnerMemberships, owner, "admin", "group");

        policy.ensureRemovalAllowed(admin, member);
        assertThrows(ForbiddenException.class, () -> policy.ensureRemovalAllowed(admin, owner));
        assertThrows(ForbiddenException.class, () -> policy.ensureRemovalAllowed(admin, secondOwner));
        assertTrue(policy.canLeave(member, soloOwnerMemberships));
        assertFalse(policy.canLeave(owner, soloOwnerMemberships));
        assertTrue(policy.canLeave(owner, multiOwnerMemberships));
    }

    @Test
    void validatesJoinEligibilityAndRequestLookup() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialCircleMembershipPolicy policy = new SocialCircleMembershipPolicy(repository, (first, second) ->
                (first.equals("blocked_user") && second.equals("owner"))
                        || (first.equals("owner") && second.equals("blocked_user")));
        List<MembershipRecord> memberships = List.of(
                membership("owner", "group_a", "owner"),
                membership("member", "group_a", "member"));
        CircleMembershipRequestRecord request = circleRequest(
                "request_a",
                "group_a",
                "candidate",
                "candidate",
                "join_request",
                "pending");
        repository.saveCircleMembershipRequest(request);
        repository.saveCircleMembershipRequest(circleRequest(
                "request_done",
                "group_a",
                "accepted_user",
                "accepted_user",
                "join_request",
                "approved"));

        policy.ensurePublicJoin("public", "group");
        policy.ensureCandidateCanJoin("candidate", "group_a", "group", memberships);
        assertThrows(ForbiddenException.class, () -> policy.ensurePublicJoin("private", "group"));
        assertThrows(WebApplicationException.class, () ->
                policy.ensureCandidateCanJoin("member", "group_a", "group", memberships));
        assertThrows(WebApplicationException.class, () ->
                policy.ensureCandidateCanJoin("blocked_user", "group_a", "group", memberships));

        assertEquals(request, policy.pendingRequest("group", "group_a", "candidate", "join_request"));
        assertEquals(request, policy.requireRequest("request_a", "group", "group_a", "join_request"));
        assertTrue(policy.requestMatchesStatus(request, "all"));
        assertTrue(policy.requestMatchesStatus(request, "pending"));
        assertFalse(policy.requestMatchesStatus(request, "approved"));
        policy.requirePendingRequest(request);
        assertThrows(WebApplicationException.class, () ->
                policy.requirePendingRequest(repository.circleMembershipRequest("request_done")));
        assertThrows(NotFoundException.class, () ->
                policy.requireRequest("request_a", "community", "community_a", "join_request"));
    }

    private static MembershipRecord membership(String memberId, String targetId, String role) {
        return new MembershipRecord(memberId, targetId, role, BASE_TIME);
    }

    private static CircleMembershipRequestRecord circleRequest(
            String requestId,
            String targetId,
            String userId,
            String actorUserId,
            String requestType,
            String status) {
        return new CircleMembershipRequestRecord(
                requestId,
                targetId,
                "group",
                userId,
                actorUserId,
                requestType,
                status,
                "",
                BASE_TIME,
                BASE_TIME);
    }
}
