package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.util.List;

final class SocialRelationshipContextResolver {
    SocialRelationshipContextResponse resolve(Signals signals, VisibilityDecision visibility) {
        String relation = relation(signals);
        return new SocialRelationshipContextResponse(
                signals.viewerId(),
                signals.ownerId(),
                relation,
                connectionDepth(signals),
                affinityScore(signals),
                signals.blocked(),
                signals.directFriend(),
                signals.viewerMarkedCloseFriend(),
                signals.ownerMarkedCloseFriend(),
                signals.familyLink(),
                signals.familyRelationship(),
                signals.pendingRequestDirection(),
                signals.mutualFriendIds().size(),
                signals.sharedGroupIds().size(),
                signals.sharedCommunityIds().size(),
                signals.mutualFriendIds(),
                signals.sharedGroupIds(),
                signals.sharedCommunityIds(),
                visibility);
    }

    private String relation(Signals signals) {
        if (signals.viewerId().equals(signals.ownerId())) {
            return "self";
        }
        if (signals.blocked()) {
            return "blocked";
        }
        if (signals.directFriend()) {
            return signals.ownerMarkedCloseFriend() ? "close_friend" : "friend";
        }
        if (signals.familyLink()) {
            return "family";
        }
        if (!signals.pendingRequestDirection().isEmpty()) {
            return signals.pendingRequestDirection();
        }
        if (connected(signals)) {
            return "connected";
        }
        return "public";
    }

    private int connectionDepth(Signals signals) {
        if (signals.viewerId().equals(signals.ownerId())) {
            return 0;
        }
        if (signals.blocked()) {
            return -1;
        }
        if (signals.directFriend() || signals.familyLink() || !signals.pendingRequestDirection().isEmpty()) {
            return 1;
        }
        if (connected(signals)) {
            return 2;
        }
        return -1;
    }

    private double affinityScore(Signals signals) {
        if (signals.viewerId().equals(signals.ownerId())) {
            return 100.0;
        }
        if (signals.blocked()) {
            return 0.0;
        }
        double score = 0.0;
        if (signals.directFriend()) {
            score += 55.0;
        }
        if (signals.ownerMarkedCloseFriend()) {
            score += 20.0;
        }
        if (signals.viewerMarkedCloseFriend()) {
            score += 10.0;
        }
        if (signals.familyLink()) {
            score += 25.0;
        }
        if (!signals.pendingRequestDirection().isEmpty()) {
            score += 8.0;
        }
        score += Math.min(signals.mutualFriendIds().size(), 5) * 6.0;
        score += Math.min(signals.sharedGroupIds().size(), 4) * 4.0;
        score += Math.min(signals.sharedCommunityIds().size(), 4) * 3.0;
        return Math.min(100.0, score);
    }

    private boolean connected(Signals signals) {
        return !signals.mutualFriendIds().isEmpty()
                || !signals.sharedGroupIds().isEmpty()
                || !signals.sharedCommunityIds().isEmpty();
    }

    record Signals(
            String viewerId,
            String ownerId,
            boolean blocked,
            boolean directFriend,
            boolean viewerMarkedCloseFriend,
            boolean ownerMarkedCloseFriend,
            boolean familyLink,
            String familyRelationship,
            String pendingRequestDirection,
            List<String> mutualFriendIds,
            List<String> sharedGroupIds,
            List<String> sharedCommunityIds) {
    }
}
