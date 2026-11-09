package tech.kayys.jezaku.presence;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class LocalPresenceAudienceAccessClientTest {
    @Test
    void allowsOnlyPublicPresenceLikeCurrentInMemoryPolicy() {
        var response = new LocalPresenceAudienceAccessClient().access(new PresenceAudienceAccessRequest(
                "viewer",
                List.of(
                        new PresenceAudienceOwner("public_owner", "public"),
                        new PresenceAudienceOwner("friends_owner", "friends"),
                        new PresenceAudienceOwner("private_owner", "private"))));

        assertTrue(response.decisionFor(record("public_owner")).canView());
        assertFalse(response.decisionFor(record("friends_owner")).canView());
        assertFalse(response.decisionFor(record("private_owner")).canView());
    }

    private PresenceRecord record(String userId) {
        return new PresenceRecord(
                userId,
                userId,
                "",
                new PresenceDtos.GeoPoint(10.0, 20.0, null),
                null,
                null,
                null,
                "public",
                100,
                "",
                java.time.Instant.EPOCH,
                java.time.Instant.EPOCH.plusSeconds(60),
                java.time.Instant.EPOCH);
    }
}
