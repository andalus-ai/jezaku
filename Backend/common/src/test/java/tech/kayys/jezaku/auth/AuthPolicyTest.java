package tech.kayys.jezaku.auth;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AuthPolicyTest {
    private static final String SECRET = "0123456789abcdef0123456789abcdef";
    private static final Instant NOW = Instant.parse("2026-11-13T10:00:00Z");

    private static String bearer(String userId, Instant expiresAt) {
        return "Bearer " + JwtTokens.issue(SECRET.getBytes(StandardCharsets.UTF_8),
                new JwtTokens.Claims(userId, "session_1", NOW.minusSeconds(60), expiresAt));
    }

    private static AuthPolicy enforced() {
        return new AuthPolicy(true, SECRET, List.of());
    }

    @Test
    void enforcedPolicyRejectsAnonymousProtectedRequests() {
        var decision = enforced().decide("GET", "/memories/nearby", null, NOW);

        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED, decision.outcome());
    }

    @Test
    void enforcedPolicyRejectsBadAndExpiredTokens() {
        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED,
                enforced().decide("GET", "/memories", "Bearer nope", NOW).outcome());
        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED,
                enforced().decide("GET", "/memories", bearer("user_1", NOW.minusSeconds(1)), NOW).outcome());
        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED,
                enforced().decide("GET", "/memories", "Basic dXNlcjpwYXNz", NOW).outcome());
    }

    @Test
    void validTokenAuthenticatesTheCaller() {
        var decision = enforced().decide("GET", "/memories", bearer("user_1", NOW.plusSeconds(600)), NOW);

        assertEquals(AuthPolicy.Outcome.AUTHENTICATED, decision.outcome());
        assertEquals("user_1", decision.user().userId());
        assertEquals("session_1", decision.user().sessionId());
    }

    @Test
    void schemeIsCaseInsensitive() {
        String lower = "bearer " + bearer("user_1", NOW.plusSeconds(600)).substring(7);

        assertEquals(AuthPolicy.Outcome.AUTHENTICATED, enforced().decide("GET", "/x", lower, NOW).outcome());
    }

    @Test
    void sessionCreationHealthAndPreflightArePublic() {
        AuthPolicy policy = enforced();

        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                policy.decide("POST", "/identity/sessions", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                policy.decide("POST", "/identity/accounts", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                policy.decide("POST", "/identity/sessions/refresh", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                policy.decide("GET", "/identity/sessions/validate", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                policy.decide("GET", "/q/health/live", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                policy.decide("OPTIONS", "/memories", null, NOW).outcome());
    }

    @Test
    void publicRulesAreMethodAndPathExact() {
        AuthPolicy policy = enforced();

        // Same path, different method, and a path that merely starts with a public one.
        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED,
                policy.decide("GET", "/identity/accounts", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED,
                policy.decide("POST", "/identity/accounts/user_1", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED,
                policy.decide("PUT", "/identity/accounts/user_1/status", null, NOW).outcome());
    }

    @Test
    void relaxedPolicyAllowsAnonymousButStillReadsValidTokens() {
        AuthPolicy relaxed = new AuthPolicy(false, SECRET, List.of());

        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS, relaxed.decide("GET", "/memories", null, NOW).outcome());
        assertEquals(AuthPolicy.Outcome.ALLOWED_ANONYMOUS,
                relaxed.decide("GET", "/memories", "Bearer garbage", NOW).outcome());
        assertEquals(AuthPolicy.Outcome.AUTHENTICATED,
                relaxed.decide("GET", "/memories", bearer("user_2", NOW.plusSeconds(60)), NOW).outcome());
    }

    @Test
    void enforcingWithoutAStrongSecretFailsFast() {
        assertThrows(IllegalStateException.class, () -> new AuthPolicy(true, null, List.of()));
        assertThrows(IllegalStateException.class, () -> new AuthPolicy(true, "too-short", List.of()));
    }
}
