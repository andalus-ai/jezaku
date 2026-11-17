package tech.kayys.jezaku.auth;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ServiceTokensTest {
    private static final byte[] SERVICE_SECRET = "service-secret-0123456789abcdef-xx".getBytes(StandardCharsets.UTF_8);
    private static final byte[] USER_SECRET = "0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8);
    private static final Instant NOW = Instant.parse("2026-11-17T10:00:00Z");

    private static String token(Instant expiresAt) {
        return ServiceTokens.issue(SERVICE_SECRET, new ServiceTokens.Claims(
                "camera", Set.of(ServiceScopes.SOCIAL_AUDIENCE), NOW, expiresAt));
    }

    @Test
    void roundTripsServiceAndScopes() {
        var claims = ServiceTokens.verify(SERVICE_SECRET, token(NOW.plusSeconds(300)), NOW.plusSeconds(5));

        assertTrue(claims.isPresent());
        assertEquals("camera", claims.get().service());
        assertEquals(Set.of(ServiceScopes.SOCIAL_AUDIENCE), claims.get().scopes());
    }

    @Test
    void rejectsExpiredWrongSecretAndTamperedTokens() {
        String token = token(NOW.plusSeconds(300));

        assertTrue(ServiceTokens.verify(SERVICE_SECRET, token, NOW.plusSeconds(300)).isEmpty());
        byte[] other = "another-secret-0123456789abcdef-x".getBytes(StandardCharsets.UTF_8);
        assertTrue(ServiceTokens.verify(other, token, NOW).isEmpty());
        assertTrue(ServiceTokens.verify(SERVICE_SECRET, token + "x", NOW).isEmpty());
        assertTrue(ServiceTokens.verify(SERVICE_SECRET, null, NOW).isEmpty());
    }

    @Test
    void refusesTokensThatLiveLongerThanTheMaximum() {
        String longLived = token(NOW.plus(ServiceTokens.MAX_LIFETIME).plusSeconds(1));

        assertTrue(ServiceTokens.verify(SERVICE_SECRET, longLived, NOW).isEmpty());
    }

    @Test
    void userAndServiceTokensAreNotInterchangeable() {
        String userToken = JwtTokens.issue(USER_SECRET,
                new JwtTokens.Claims("user_1", "s1", NOW, NOW.plusSeconds(300)));
        // Same secret on purpose: the issuer and claim shape alone must keep them apart.
        String serviceToken = ServiceTokens.issue(USER_SECRET, new ServiceTokens.Claims(
                "camera", Set.of(), NOW, NOW.plusSeconds(300)));

        assertTrue(ServiceTokens.verify(USER_SECRET, userToken, NOW).isEmpty());
        assertTrue(JwtTokens.verify(USER_SECRET, serviceToken, NOW).isEmpty());
    }

    @Test
    void weakSecretsAreRejected() {
        assertThrows(IllegalStateException.class, () -> ServiceTokens.issue(
                "short".getBytes(StandardCharsets.UTF_8),
                new ServiceTokens.Claims("camera", Set.of(), NOW, NOW.plusSeconds(60))));
    }
}
