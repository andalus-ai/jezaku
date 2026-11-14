package tech.kayys.jezaku.auth;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtTokensTest {
    private static final byte[] SECRET = "0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8);
    private static final Instant NOW = Instant.parse("2026-11-13T10:00:00Z");

    private static JwtTokens.Claims claims(Instant issuedAt, Instant expiresAt) {
        return new JwtTokens.Claims("user_1", "session_1", issuedAt, expiresAt);
    }

    private static String token() {
        return JwtTokens.issue(SECRET, claims(NOW, NOW.plusSeconds(900)));
    }

    @Test
    void roundTripsClaims() {
        var verified = JwtTokens.verify(SECRET, token(), NOW.plusSeconds(10));

        assertTrue(verified.isPresent());
        assertEquals("user_1", verified.get().userId());
        assertEquals("session_1", verified.get().sessionId());
        assertEquals(NOW.plusSeconds(900), verified.get().expiresAt());
    }

    @Test
    void rejectsExpiredTokens() {
        assertTrue(JwtTokens.verify(SECRET, token(), NOW.plusSeconds(900)).isEmpty());
        assertTrue(JwtTokens.verify(SECRET, token(), NOW.plusSeconds(5_000)).isEmpty());
    }

    @Test
    void rejectsTokensIssuedFarInTheFuture() {
        String future = JwtTokens.issue(SECRET, claims(NOW.plusSeconds(600), NOW.plusSeconds(1_500)));

        assertTrue(JwtTokens.verify(SECRET, future, NOW).isEmpty());
    }

    @Test
    void rejectsWrongSecretAndTamperedPayload() {
        byte[] other = "ffffffffffffffffffffffffffffffff".getBytes(StandardCharsets.UTF_8);
        assertTrue(JwtTokens.verify(other, token(), NOW).isEmpty());

        String[] parts = token().split("\\.");
        String forgedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(
                ("{\"iss\":\"jezaku-identity\",\"sub\":\"admin\",\"sid\":\"session_1\",\"iat\":"
                        + NOW.getEpochSecond() + ",\"exp\":" + NOW.plusSeconds(900).getEpochSecond() + "}")
                        .getBytes(StandardCharsets.UTF_8));
        assertTrue(JwtTokens.verify(SECRET, parts[0] + "." + forgedPayload + "." + parts[2], NOW).isEmpty());
    }

    @Test
    void rejectsAlgNoneAndUnsignedTokens() {
        String header = Base64.getUrlEncoder().withoutPadding()
                .encodeToString("{\"alg\":\"none\",\"typ\":\"JWT\"}".getBytes(StandardCharsets.UTF_8));
        String payload = token().split("\\.")[1];

        assertTrue(JwtTokens.verify(SECRET, header + "." + payload + ".", NOW).isEmpty());
        assertTrue(JwtTokens.verify(SECRET, header + "." + payload, NOW).isEmpty());
    }

    @Test
    void rejectsGarbage() {
        assertTrue(JwtTokens.verify(SECRET, null, NOW).isEmpty());
        assertTrue(JwtTokens.verify(SECRET, "", NOW).isEmpty());
        assertTrue(JwtTokens.verify(SECRET, "a.b.c", NOW).isEmpty());
        assertTrue(JwtTokens.verify(SECRET, "x".repeat(5_000), NOW).isEmpty());
    }

    @Test
    void refusesShortSecrets() {
        byte[] weak = "short".getBytes(StandardCharsets.UTF_8);

        assertThrows(IllegalStateException.class, () -> JwtTokens.issue(weak, claims(NOW, NOW.plusSeconds(60))));
        assertThrows(IllegalStateException.class, () -> JwtTokens.verify(weak, token(), NOW));
    }
}
