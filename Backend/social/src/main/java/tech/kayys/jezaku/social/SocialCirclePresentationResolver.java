package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleOwnershipTransferResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.util.List;
import java.util.Objects;

final class SocialCirclePresentationResolver {
    private final SocialCircleGraphStore repository;
    private final SocialCircleMembershipPolicy membershipPolicy;

    SocialCirclePresentationResolver(
            SocialCircleGraphStore repository,
            SocialCircleMembershipPolicy membershipPolicy) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.membershipPolicy = Objects.requireNonNull(membershipPolicy, "membershipPolicy");
    }

    SocialGroupResponse group(SocialGroupRecord group, String viewerId) {
        List<MembershipRecord> memberships = repository.groupMemberships();
        int memberCount = memberCount(memberships, group.groupId());
        SocialCircleMembershipPolicy.ViewerState viewerState = membershipPolicy.viewerState(
                "group",
                group.groupId(),
                group.visibility(),
                memberships,
                viewerId);
        return new SocialGroupResponse(
                group.groupId(),
                group.name(),
                group.visibility(),
                group.createdAt(),
                memberCount,
                viewerState.role(),
                viewerState.member(),
                viewerState.pendingJoinRequest(),
                viewerState.pendingInvite(),
                viewerState.blocked(),
                viewerState.canJoin(),
                viewerState.canRequestJoin(),
                viewerState.canLeave());
    }

    SocialCommunityResponse community(SocialCommunityRecord community, String viewerId) {
        List<MembershipRecord> memberships = repository.communityMemberships();
        int memberCount = memberCount(memberships, community.communityId());
        SocialCircleMembershipPolicy.ViewerState viewerState = membershipPolicy.viewerState(
                "community",
                community.communityId(),
                community.visibility(),
                memberships,
                viewerId);
        return new SocialCommunityResponse(
                community.communityId(),
                community.name(),
                community.visibility(),
                community.createdAt(),
                memberCount,
                viewerState.role(),
                viewerState.member(),
                viewerState.pendingJoinRequest(),
                viewerState.pendingInvite(),
                viewerState.blocked(),
                viewerState.canJoin(),
                viewerState.canRequestJoin(),
                viewerState.canLeave());
    }

    MembershipResponse membership(MembershipRecord membership, String targetType) {
        return new MembershipResponse(
                membership.memberId(),
                membership.targetId(),
                targetType,
                membership.role(),
                membership.createdAt());
    }

    CircleMembershipRequestResponse membershipRequest(CircleMembershipRequestRecord request) {
        return new CircleMembershipRequestResponse(
                request.requestId(),
                request.targetId(),
                request.targetType(),
                request.userId(),
                request.actorUserId(),
                request.requestType(),
                request.status(),
                request.message(),
                request.createdAt(),
                request.updatedAt());
    }

    CircleContentModerationResponse contentModeration(CircleContentModerationRecord moderation) {
        return new CircleContentModerationResponse(
                moderation.moderationId(),
                moderation.contentId(),
                moderation.targetId(),
                moderation.targetType(),
                moderation.actorUserId(),
                moderation.action(),
                moderation.status(),
                moderation.reason(),
                moderation.createdAt(),
                moderation.updatedAt());
    }

    CircleOwnershipTransferResponse ownershipTransfer(SocialCircleOwnershipTransferResult transfer) {
        return new CircleOwnershipTransferResponse(
                transfer.targetId(),
                transfer.targetType(),
                transfer.previousOwnerId(),
                transfer.newOwnerId(),
                transfer.previousOwnerRole(),
                transfer.newOwnerRole(),
                transfer.transferredAt());
    }

    private int memberCount(List<MembershipRecord> memberships, String targetId) {
        return (int) memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .count();
    }
}
