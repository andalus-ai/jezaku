package tech.kayys.jezaku.presence;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PresenceVisibilityPolicyTest {
    private final PresenceVisibilityPolicy policy = new PresenceVisibilityPolicy();

    @Test
    void allowsPublicPresenceInsideShareRadius() {
        var decision = policy.decide("viewer", record("owner", "public", 100), 40.0);

        assertTrue(decision.visible());
        assertEquals(PresenceVisibilityPolicy.REASON_VISIBLE, decision.reason());
    }

    @Test
    void hidesViewerOwnPresenceFromNearbyResults() {
        var decision = policy.decide("viewer", record("viewer", "public", 100), 1.0);

        assertFalse(decision.visible());
        assertEquals(PresenceVisibilityPolicy.REASON_SELF_EXCLUDED, decision.reason());
    }

    @Test
    void hidesNonPublicPresenceUntilSocialAdapterCanAuthorizeIt() {
        var decision = policy.decide("viewer", record("owner", "friends", 100), 20.0);

        assertFalse(decision.visible());
        assertEquals(PresenceVisibilityPolicy.REASON_VISIBILITY_HIDDEN, decision.reason());
    }

    @Test
    void allowsAudienceAuthorizedPresenceWithAudienceReason() {
        var decision = policy.decide(
                "viewer",
                record("owner", "friends", 100),
                20.0,
                PresenceAudienceAccessDecision.allow("owner", "friend"));

        assertTrue(decision.visible());
        assertEquals("friend", decision.reason());
    }

    @Test
    void hidesAudienceDeniedPresenceWithAudienceReason() {
        var decision = policy.decide(
                "viewer",
                record("owner", "public", 100),
                20.0,
                PresenceAudienceAccessDecision.deny("owner", "blocked"));

        assertFalse(decision.visible());
        assertEquals("blocked", decision.reason());
    }

    @Test
    void hidesPresenceOutsideOwnerShareRadius() {
        var decision = policy.decide("viewer", record("owner", "public", 25), 40.0);

        assertFalse(decision.visible());
        assertEquals(PresenceVisibilityPolicy.REASON_OUTSIDE_SHARE_RADIUS, decision.reason());
    }

    private PresenceRecord record(String userId, String visibility, int shareRadiusMeters) {
        Instant now = Instant.parse("2026-06-07T00:00:00Z");
        return new PresenceRecord(
                userId,
                userId,
                "",
                new GeoPoint(10.0, 20.0, 100.0),
                null,
                null,
                null,
                visibility,
                shareRadiusMeters,
                "",
                now,
                now.plusSeconds(120),
                now);
    }
}
