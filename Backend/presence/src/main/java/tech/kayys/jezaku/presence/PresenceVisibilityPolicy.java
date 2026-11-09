package tech.kayys.jezaku.presence;

import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
class PresenceVisibilityPolicy {
    static final String REASON_VISIBLE = "visible";
    static final String REASON_SELF_EXCLUDED = "self_excluded";
    static final String REASON_VISIBILITY_HIDDEN = "visibility_hidden";
    static final String REASON_OUTSIDE_SHARE_RADIUS = "outside_share_radius";

    PresenceVisibilityDecision decide(String viewerId, PresenceRecord record, double distanceMeters) {
        return decide(viewerId, record, distanceMeters, localAudienceDecision(record));
    }

    PresenceVisibilityDecision decide(
            String viewerId,
            PresenceRecord record,
            double distanceMeters,
            PresenceAudienceAccessDecision audienceDecision) {
        if (sameUser(viewerId, record.userId())) {
            return hidden(REASON_SELF_EXCLUDED);
        }
        if (audienceDecision == null || !audienceDecision.canView()) {
            return hidden(audienceDecision == null ? REASON_VISIBILITY_HIDDEN : audienceDecision.reason());
        }
        if (distanceMeters > record.shareRadiusMeters()) {
            return hidden(REASON_OUTSIDE_SHARE_RADIUS);
        }
        return new PresenceVisibilityDecision(true, audienceDecision.reason());
    }

    private PresenceAudienceAccessDecision localAudienceDecision(PresenceRecord record) {
        if ("public".equals(record.visibility())) {
            return PresenceAudienceAccessDecision.allow(record.userId(), REASON_VISIBLE);
        }
        return PresenceAudienceAccessDecision.deny(record.userId(), REASON_VISIBILITY_HIDDEN);
    }

    private PresenceVisibilityDecision hidden(String reason) {
        return new PresenceVisibilityDecision(false, reason);
    }

    private boolean sameUser(String viewerId, String ownerId) {
        return viewerId != null && !viewerId.isBlank() && viewerId.equals(ownerId);
    }

    record PresenceVisibilityDecision(boolean visible, String reason) {
    }
}
