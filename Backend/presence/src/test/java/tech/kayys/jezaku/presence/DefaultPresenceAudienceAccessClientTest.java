package tech.kayys.jezaku.presence;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DefaultPresenceAudienceAccessClientTest {
    @Test
    void reportsHealthyLocalSourceByDefault() {
        DefaultPresenceAudienceAccessClient client = client("local", Optional.empty(), true);

        var health = client.health();

        assertEquals("local", health.requestedSource());
        assertEquals("local", health.effectiveSource());
        assertEquals("healthy", health.health());
        assertTrue(health.ready());
    }

    @Test
    void reportsConfiguredSocialSourceAsHealthy() {
        DefaultPresenceAudienceAccessClient client = client("http", Optional.of("http://social.local"), true);

        var health = client.health();

        assertEquals("http", health.requestedSource());
        assertEquals("social", health.effectiveSource());
        assertEquals("healthy", health.health());
        assertTrue(health.ready());
        assertTrue(health.socialBaseUrlConfigured());
    }

    @Test
    void reportsMissingSocialUrlAsDegradedWhenFallbackIsEnabled() {
        DefaultPresenceAudienceAccessClient client = client("http", Optional.empty(), true);

        var health = client.health();

        assertEquals("degraded", health.health());
        assertEquals("local", health.effectiveSource());
        assertTrue(health.ready());
        assertTrue(health.fallbackToLocal());
        assertTrue(health.issues().contains("social_base_url_missing"));
    }

    @Test
    void reportsMissingSocialUrlAsCriticalWithoutFallback() {
        DefaultPresenceAudienceAccessClient client = client("http", Optional.empty(), false);

        var health = client.health();

        assertEquals("critical", health.health());
        assertEquals("none", health.effectiveSource());
        assertFalse(health.ready());
    }

    @Test
    void tagsHttpFallbackDecisionsAsLocalFallback() {
        DefaultPresenceAudienceAccessClient client = client("http", Optional.empty(), true);

        var response = client.access(new PresenceAudienceAccessRequest(
                "viewer",
                List.of(new PresenceAudienceOwner("owner", "public"))));

        assertEquals("local", response.source());
        assertTrue(response.fallback());
        assertTrue(response.decisionFor(record("owner")).canView());
    }

    private DefaultPresenceAudienceAccessClient client(
            String source,
            Optional<String> socialBaseUrl,
            boolean fallbackToLocal) {
        DefaultPresenceAudienceAccessClient client = new DefaultPresenceAudienceAccessClient();
        client.source = source;
        client.socialBaseUrl = socialBaseUrl;
        client.fallbackToLocal = fallbackToLocal;
        return client;
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
