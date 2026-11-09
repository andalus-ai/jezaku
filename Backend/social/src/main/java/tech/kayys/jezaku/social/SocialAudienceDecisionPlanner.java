package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.List;
import java.util.Objects;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialAudienceDecisionPlanner {
    private final SocialGraphRepository repository;
    private final Access access;

    SocialAudienceDecisionPlanner(SocialGraphRepository repository, Access access) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.access = Objects.requireNonNull(access, "access");
    }

    SocialAudienceDecisionResponse decision(String ownerId, String viewerId, String scope, String targetId) {
        SocialRelationshipContextResponse context = access.relationshipContext(ownerId, viewerId);
        if (ownerId.equals(viewerId)) {
            return ownerDecision(ownerId, viewerId, scope, targetId, context);
        }
        if (context.blocked()) {
            return decisionResponse(ownerId, viewerId, scope, "", false, "blocked", false, false, context);
        }

        return switch (scope) {
            case "public" -> decisionResponse(
                    ownerId,
                    viewerId,
                    scope,
                    "",
                    true,
                    "public",
                    false,
                    false,
                    context);
            case "private" -> decisionResponse(
                    ownerId,
                    viewerId,
                    scope,
                    "",
                    false,
                    "private",
                    false,
                    false,
                    context);
            case "friends" -> decisionResponse(
                    ownerId,
                    viewerId,
                    scope,
                    "",
                    context.directFriend(),
                    context.directFriend() ? "friend" : "not_friend",
                    false,
                    false,
                    context);
            case "close_friends" -> decisionResponse(
                    ownerId,
                    viewerId,
                    scope,
                    "",
                    context.viewerMarkedCloseFriend(),
                    context.viewerMarkedCloseFriend() ? "close_friend" : "not_close_friend",
                    false,
                    false,
                    context);
            case "family" -> decisionResponse(
                    ownerId,
                    viewerId,
                    scope,
                    "",
                    context.familyLink(),
                    context.familyLink() ? "family" : "not_family",
                    false,
                    false,
                    context);
            case "group" -> targetDecision(
                    ownerId,
                    viewerId,
                    scope,
                    requireAudienceTarget(targetId, "group"),
                    repository.groupMemberships(),
                    "group_member",
                    "not_group_member",
                    "owner_not_group_member",
                    context);
            case "community" -> targetDecision(
                    ownerId,
                    viewerId,
                    scope,
                    requireAudienceTarget(targetId, "community"),
                    repository.communityMemberships(),
                    "community_member",
                    "not_community_member",
                    "owner_not_community_member",
                    context);
            default -> throw new BadRequestException("Unsupported audience scope: " + scope);
        };
    }

    private SocialAudienceDecisionResponse ownerDecision(
            String ownerId,
            String viewerId,
            String scope,
            String targetId,
            SocialRelationshipContextResponse context) {
        return switch (scope) {
            case "group" -> ownerTargetDecision(
                    ownerId,
                    viewerId,
                    scope,
                    requireAudienceTarget(targetId, "group"),
                    repository.groupMemberships(),
                    context);
            case "community" -> ownerTargetDecision(
                    ownerId,
                    viewerId,
                    scope,
                    requireAudienceTarget(targetId, "community"),
                    repository.communityMemberships(),
                    context);
            case "public", "private", "friends", "close_friends", "family" -> decisionResponse(
                    ownerId,
                    viewerId,
                    scope,
                    "",
                    true,
                    "owner",
                    false,
                    false,
                    context);
            default -> throw new BadRequestException("Unsupported audience scope: " + scope);
        };
    }

    private SocialAudienceDecisionResponse ownerTargetDecision(
            String ownerId,
            String viewerId,
            String scope,
            String targetId,
            List<MembershipRecord> memberships,
            SocialRelationshipContextResponse context) {
        if ("group".equals(scope)) {
            requireGroup(targetId);
        } else {
            requireCommunity(targetId);
        }
        return decisionResponse(
                ownerId,
                viewerId,
                scope,
                targetId,
                true,
                "owner",
                true,
                memberOf(memberships, ownerId, targetId),
                context);
    }

    private SocialAudienceDecisionResponse targetDecision(
            String ownerId,
            String viewerId,
            String scope,
            String targetId,
            List<MembershipRecord> memberships,
            String allowReason,
            String denyReason,
            String ownerDenyReason,
            SocialRelationshipContextResponse context) {
        if ("group".equals(scope)) {
            requireGroup(targetId);
        } else {
            requireCommunity(targetId);
        }
        boolean ownerMember = memberOf(memberships, ownerId, targetId);
        boolean viewerMember = memberOf(memberships, viewerId, targetId);
        boolean canView = ownerMember && viewerMember;
        String reason = !ownerMember ? ownerDenyReason : viewerMember ? allowReason : denyReason;
        return decisionResponse(
                ownerId,
                viewerId,
                scope,
                targetId,
                canView,
                reason,
                true,
                viewerMember,
                context);
    }

    private SocialAudienceDecisionResponse decisionResponse(
            String ownerId,
            String viewerId,
            String scope,
            String targetId,
            boolean canView,
            String reason,
            boolean targetRequired,
            boolean viewerTargetMember,
            SocialRelationshipContextResponse context) {
        return new SocialAudienceDecisionResponse(
                ownerId,
                viewerId,
                scope,
                targetId,
                canView,
                reason,
                context.relation(),
                context.blocked(),
                ownerId.equals(viewerId),
                targetRequired,
                viewerTargetMember,
                context.visibility());
    }

    private String requireAudienceTarget(String targetId, String scope) {
        return requireText(targetId, "targetId for " + scope + " audience");
    }

    private void requireGroup(String groupId) {
        String normalizedGroupId = requireText(groupId, "groupId");
        if (repository.group(normalizedGroupId) == null) {
            throw new NotFoundException("Group not found: " + normalizedGroupId);
        }
    }

    private void requireCommunity(String communityId) {
        String normalizedCommunityId = requireText(communityId, "communityId");
        if (repository.community(normalizedCommunityId) == null) {
            throw new NotFoundException("Community not found: " + normalizedCommunityId);
        }
    }

    private boolean memberOf(List<MembershipRecord> memberships, String memberId, String targetId) {
        return memberships.stream()
                .anyMatch(membership -> membership.memberId().equals(memberId)
                        && membership.targetId().equals(targetId));
    }

    interface Access {
        SocialRelationshipContextResponse relationshipContext(String ownerId, String viewerId);
    }
}
