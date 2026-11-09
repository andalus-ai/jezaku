package tech.kayys.jezaku.presence;

import tech.kayys.jezaku.presence.PresenceDtos.PresenceAudienceAccessHealth;

interface PresenceAudienceAccessClient {
    PresenceAudienceAccessResponse access(PresenceAudienceAccessRequest request);

    PresenceAudienceAccessHealth health();
}
