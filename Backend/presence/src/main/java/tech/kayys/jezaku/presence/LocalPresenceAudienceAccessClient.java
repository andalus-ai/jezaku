package tech.kayys.jezaku.presence;

import tech.kayys.jezaku.presence.PresenceDtos.PresenceAudienceAccessHealth;

import java.util.List;

class LocalPresenceAudienceAccessClient implements PresenceAudienceAccessClient {
    @Override
    public PresenceAudienceAccessResponse access(PresenceAudienceAccessRequest request) {
        return new PresenceAudienceAccessResponse(
                request.viewerId(),
                request.owners().stream()
                        .map(this::decision)
                        .toList());
    }

    private PresenceAudienceAccessDecision decision(PresenceAudienceOwner owner) {
        if ("public".equals(owner.visibility())) {
            return PresenceAudienceAccessDecision.allow(owner.ownerId(), PresenceVisibilityPolicy.REASON_VISIBLE);
        }
        return PresenceAudienceAccessDecision.deny(
                owner.ownerId(),
                PresenceVisibilityPolicy.REASON_VISIBILITY_HIDDEN);
    }

    @Override
    public PresenceAudienceAccessHealth health() {
        return new PresenceAudienceAccessHealth(
                "local",
                "local",
                "healthy",
                true,
                false,
                false,
                List.of(),
                List.of());
    }
}
