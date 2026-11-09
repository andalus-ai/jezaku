package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCirclePresentationResolverTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T11:00:00Z");

    @Test
    void hydratesGroupResponseWithMembershipCountsAndViewerState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroupMembership(membership("owner", "group_a", "owner"));
        repository.saveGroupMembership(membership("member", "group_a", "member"));
        repository.saveCircleMembershipRequest(circleRequest(
                "join_request_a",
                "group",
                "group_a",
                "pending_user",
                "pending_user",
                "join_request",
                "pending"));
        repository.saveCircleMembershipRequest(circleRequest(
                "invite_a",
                "group",
                "group_a",
                "invited_user",
                "owner",
                "invite",
                "pending"));
        SocialCirclePresentationResolver resolver = resolver(repository, true);
        SocialGroupRecord publicGroup = new SocialGroupRecord("group_a", "Creators", "public", BASE_TIME);
        SocialGroupRecord privateGroup = new SocialGroupRecord("group_a", "Creators", "private", BASE_TIME);

        SocialGroupResponse member = resolver.group(publicGroup, "member");
        SocialGroupResponse pending = resolver.group(publicGroup, "pending_user");
        SocialGroupResponse invited = resolver.group(publicGroup, "invited_user");
        SocialGroupResponse visitor = resolver.group(publicGroup, "visitor");
        SocialGroupResponse privateVisitor = resolver.group(privateGroup, "private_visitor");
        SocialGroupResponse blocked = resolver.group(publicGroup, "blocked_user");

        assertEquals("group_a", member.groupId());
        assertEquals("Creators", member.name());
        assertEquals(2, member.memberCount());
        assertTrue(member.viewerMember());
        assertEquals("member", member.viewerRole());
        assertTrue(member.canLeave());
        assertTrue(pending.viewerPendingJoinRequest());
        assertFalse(pending.canJoin());
        assertTrue(invited.viewerPendingInvite());
        assertFalse(invited.canJoin());
        assertTrue(visitor.canJoin());
        assertFalse(visitor.canRequestJoin());
        assertFalse(privateVisitor.canJoin());
        assertTrue(privateVisitor.canRequestJoin());
        assertTrue(blocked.viewerBlocked());
        assertFalse(blocked.canJoin());
        assertFalse(blocked.canRequestJoin());
    }

    @Test
    void hydratesCommunityResponseWithMembershipCountsAndViewerState() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroupMembership(membership("owner", "group_a", "owner"));
        repository.saveCommunityMembership(membership("owner", "community_a", "owner"));
        repository.saveCommunityMembership(membership("member", "community_a", "member"));
        repository.saveCircleMembershipRequest(circleRequest(
                "community_join_request_a",
                "community",
                "community_a",
                "pending_user",
                "pending_user",
                "join_request",
                "pending"));
        SocialCirclePresentationResolver resolver = resolver(repository, false);
        SocialCommunityRecord community = new SocialCommunityRecord(
                "community_a",
                "City Lens",
                "private",
                BASE_TIME.plusSeconds(1));

        SocialCommunityResponse member = resolver.community(community, "member");
        SocialCommunityResponse pending = resolver.community(community, "pending_user");
        SocialCommunityResponse visitor = resolver.community(community, "visitor");

        assertEquals("community_a", member.communityId());
        assertEquals("City Lens", member.name());
        assertEquals(2, member.memberCount());
        assertTrue(member.viewerMember());
        assertEquals("member", member.viewerRole());
        assertTrue(pending.viewerPendingJoinRequest());
        assertFalse(pending.canRequestJoin());
        assertFalse(visitor.canJoin());
        assertTrue(visitor.canRequestJoin());
    }

    @Test
    void mapsMembershipRequestAndModerationRecords() {
        SocialCirclePresentationResolver resolver = resolver(new InMemorySocialGraphRepository(), false);
        MembershipRecord membership = membership("member", "group_a", "admin");
        CircleMembershipRequestRecord request = circleRequest(
                "request_a",
                "group",
                "group_a",
                "candidate",
                "owner",
                "invite",
                "accepted");
        CircleContentModerationRecord moderation = new CircleContentModerationRecord(
                "moderation_a",
                "content_a",
                "group_a",
                "group",
                "owner",
                "remove",
                "removed",
                "off topic",
                BASE_TIME.plusSeconds(2),
                BASE_TIME.plusSeconds(3));

        MembershipResponse membershipResponse = resolver.membership(membership, "group");
        CircleMembershipRequestResponse requestResponse = resolver.membershipRequest(request);
        CircleContentModerationResponse moderationResponse = resolver.contentModeration(moderation);

        assertEquals("member", membershipResponse.memberId());
        assertEquals("group_a", membershipResponse.targetId());
        assertEquals("group", membershipResponse.targetType());
        assertEquals("admin", membershipResponse.role());
        assertEquals("request_a", requestResponse.requestId());
        assertEquals("candidate", requestResponse.userId());
        assertEquals("accepted", requestResponse.status());
        assertEquals("moderation_a", moderationResponse.moderationId());
        assertEquals("content_a", moderationResponse.contentId());
        assertEquals("removed", moderationResponse.status());
        assertEquals("off topic", moderationResponse.reason());
    }

    private static SocialCirclePresentationResolver resolver(
            InMemorySocialGraphRepository repository,
            boolean includeOwnerBlock) {
        SocialCircleMembershipPolicy policy = new SocialCircleMembershipPolicy(repository, (first, second) ->
                includeOwnerBlock
                        && (first.equals("blocked_user") && second.equals("owner")
                        || first.equals("owner") && second.equals("blocked_user")));
        return new SocialCirclePresentationResolver(repository, policy);
    }

    private static MembershipRecord membership(String memberId, String targetId, String role) {
        return new MembershipRecord(memberId, targetId, role, BASE_TIME);
    }

    private static CircleMembershipRequestRecord circleRequest(
            String requestId,
            String targetType,
            String targetId,
            String userId,
            String actorUserId,
            String requestType,
            String status) {
        return new CircleMembershipRequestRecord(
                requestId,
                targetId,
                targetType,
                userId,
                actorUserId,
                requestType,
                status,
                "",
                BASE_TIME,
                BASE_TIME);
    }
}
