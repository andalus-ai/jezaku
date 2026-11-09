package tech.kayys.jezaku.presence;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HttpPresenceAudienceAccessClientTest {
    @Test
    void buildsSocialAudienceAccessUri() {
        HttpPresenceAudienceAccessClient client = client();

        assertEquals("http://social.local/social/audience/access", client.audienceAccessUri().toString());
    }

    @Test
    void serializesSocialAudienceAccessRequest() throws Exception {
        HttpPresenceAudienceAccessClient client = client();

        String json = client.requestJson(
                "viewer",
                "friends",
                List.of(
                        new PresenceAudienceOwner("owner_a", "friends"),
                        new PresenceAudienceOwner("owner_b", "friends"),
                        new PresenceAudienceOwner("owner_a", "friends")));

        JsonNode root = objectMapper().readTree(json);
        assertEquals("viewer", root.get("viewerId").asText());
        assertEquals("friends", root.get("scope").asText());
        assertEquals("", root.get("targetId").asText());
        assertEquals(2, root.get("ownerIds").size());
        assertEquals("owner_a", root.get("ownerIds").get(0).asText());
        assertEquals("owner_b", root.get("ownerIds").get(1).asText());
    }

    @Test
    void mapsSocialAudienceDecisionReasons() {
        HttpPresenceAudienceAccessClient client = client();

        PresenceAudienceAccessResponse response = client.responseFromJson("""
                {
                  "viewerId": "viewer",
                  "scope": "friends",
                  "decisions": [
                    { "ownerId": "owner_friend", "canView": true, "reason": "friend" },
                    { "ownerId": "owner_blocked", "canView": false, "reason": "blocked" }
                  ]
                }
                """, "viewer");

        assertEquals("social", response.source());
        assertFalse(response.fallback());
        assertTrue(response.decisionFor(record("owner_friend")).canView());
        assertEquals("friend", response.decisionFor(record("owner_friend")).reason());
        assertFalse(response.decisionFor(record("owner_blocked")).canView());
        assertEquals("blocked", response.decisionFor(record("owner_blocked")).reason());
    }

    @Test
    void mapsLegacyAllowedAndDeniedBucketsWhenDecisionsAreAbsent() {
        HttpPresenceAudienceAccessClient client = client();

        PresenceAudienceAccessResponse response = client.responseFromJson("""
                {
                  "allowedOwnerIds": ["owner_public"],
                  "deniedOwnerIds": ["owner_hidden"]
                }
                """, "viewer");

        assertTrue(response.decisionFor(record("owner_public")).canView());
        assertFalse(response.decisionFor(record("owner_hidden")).canView());
    }

    @Test
    void normalizesInvalidTimeoutToDefault() {
        HttpPresenceAudienceAccessClient client = new HttpPresenceAudienceAccessClient(
                objectMapper(),
                Optional.of("http://social.local"),
                0);

        assertEquals(3, client.requestTimeout().toSeconds());
    }

    private HttpPresenceAudienceAccessClient client() {
        return new HttpPresenceAudienceAccessClient(
                objectMapper(),
                Optional.of("http://social.local/"),
                3);
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

    private ObjectMapper objectMapper() {
        return new ObjectMapper().findAndRegisterModules();
    }
}
