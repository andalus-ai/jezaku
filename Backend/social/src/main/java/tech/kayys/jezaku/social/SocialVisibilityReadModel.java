package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.util.Objects;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialVisibilityReadModel {
    private final SocialRelationshipPolicy relationshipPolicy;

    SocialVisibilityReadModel(SocialRelationshipPolicy relationshipPolicy) {
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
    }

    VisibilityDecision visibility(String viewerId, String ownerId) {
        String viewer = requireText(viewerId, "viewerId");
        String owner = requireText(ownerId, "ownerId");
        return decisionFor(viewer, owner);
    }

    VisibilityDecision decisionFor(String viewerId, String ownerId) {
        if (viewerId.equals(ownerId)) {
            return decision(viewerId, ownerId, "self", true, false, true, true, "self");
        }
        if (relationshipPolicy.blockedEitherWay(viewerId, ownerId)) {
            return decision(viewerId, ownerId, "blocked", false, false, false, false, "blocked");
        }
        if (relationshipPolicy.friends(viewerId, ownerId)) {
            boolean close = relationshipPolicy.closeFriend(ownerId, viewerId);
            String relation = close ? "close_friend" : "friend";
            return decision(viewerId, ownerId, relation, true, false, true, true, relation);
        }
        FriendRequestRecord pending = relationshipPolicy.pendingFriendRequestBetween(viewerId, ownerId);
        if (pending != null) {
            String relation = pending.fromUserId().equals(viewerId) ? "pending_outgoing" : "pending_incoming";
            return decision(viewerId, ownerId, relation, true, false, false, false, "pending_request");
        }
        return decision(viewerId, ownerId, "public", true, true, false, false, "public");
    }

    private VisibilityDecision decision(
            String viewerId,
            String ownerId,
            String relation,
            boolean canViewProfile,
            boolean canSendFriendRequest,
            boolean canInteract,
            boolean canSeeLocation,
            String reason) {
        return new VisibilityDecision(viewerId, ownerId, relation, canViewProfile, canSendFriendRequest, canInteract,
                canSeeLocation, reason);
    }
}
