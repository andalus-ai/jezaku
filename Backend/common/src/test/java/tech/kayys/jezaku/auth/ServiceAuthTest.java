package tech.kayys.jezaku.auth;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.container.ContainerRequestContext;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ServiceAuthTest {
    private static final String USER_SECRET = "0123456789abcdef0123456789abcdef";
    private static final String SERVICE_SECRET = "service-secret-0123456789abcdef-xx";
    private static final Instant NOW = Instant.parse("2026-11-17T10:00:00Z");

    private static String serviceBearer(String service, Set<String> scopes) {
        return "Bearer " + ServiceTokens.issue(SERVICE_SECRET.getBytes(StandardCharsets.UTF_8),
                new ServiceTokens.Claims(service, scopes, NOW.minusSeconds(5), NOW.plusSeconds(120)));
    }

    private static String userBearer(String userId) {
        return "Bearer " + JwtTokens.issue(USER_SECRET.getBytes(StandardCharsets.UTF_8),
                new JwtTokens.Claims(userId, "s1", NOW.minusSeconds(5), NOW.plusSeconds(120)));
    }

    private static AuthPolicy enforced() {
        return new AuthPolicy(true, USER_SECRET, SERVICE_SECRET, List.of());
    }

    private static ContainerRequestContext context(Object... properties) {
        Map<String, Object> values = new HashMap<>();
        for (Object property : properties) {
            if (property instanceof AuthenticatedUser user) {
                values.put(AuthFilter.USER_PROPERTY, user);
            } else if (property instanceof AuthenticatedService service) {
                values.put(AuthFilter.SERVICE_PROPERTY, service);
            }
        }
        return (ContainerRequestContext) Proxy.newProxyInstance(
                ServiceAuthTest.class.getClassLoader(),
                new Class<?>[] {ContainerRequestContext.class},
                (proxy, method, args) -> "getProperty".equals(method.getName()) ? values.get((String) args[0]) : null);
    }

    private static AuthenticatedService service(String... scopes) {
        return new AuthenticatedService("camera", Set.of(scopes));
    }

    @Test
    void policyAuthenticatesAServiceToken() {
        var decision = enforced().decide("POST", "/social/audience/access",
                serviceBearer("camera", Set.of(ServiceScopes.SOCIAL_AUDIENCE)), NOW);

        assertEquals(AuthPolicy.Outcome.SERVICE, decision.outcome());
        assertEquals("camera", decision.service().name());
        assertTrue(decision.service().hasScope(ServiceScopes.SOCIAL_AUDIENCE));
        assertEquals(null, decision.user());
    }

    @Test
    void policyKeepsUserTokensAsUsers() {
        var decision = enforced().decide("GET", "/memories", userBearer("user_1"), NOW);

        assertEquals(AuthPolicy.Outcome.AUTHENTICATED, decision.outcome());
        assertEquals("user_1", decision.user().userId());
    }

    @Test
    void serviceTokensAreRejectedWhenNoServiceSecretIsConfigured() {
        AuthPolicy withoutServiceSecret = new AuthPolicy(true, USER_SECRET, List.of());

        assertEquals(AuthPolicy.Outcome.UNAUTHENTICATED, withoutServiceSecret.decide("POST", "/x",
                serviceBearer("camera", Set.of()), NOW).outcome());
    }

    @Test
    void servicesAndUsersMustNotShareASecret() {
        assertThrows(IllegalStateException.class,
                () -> new AuthPolicy(true, USER_SECRET, USER_SECRET, List.of()));
        assertThrows(IllegalStateException.class,
                () -> new AuthPolicy(true, USER_SECRET, "too-short", List.of()));
    }

    @Test
    void requireServiceAcceptsOnlyAServiceWithTheScope() {
        assertDoesNotThrow(() -> AuthContext.requireService(
                context(service(ServiceScopes.NOTIFICATION_INTAKE)), ServiceScopes.NOTIFICATION_INTAKE));
        assertThrows(ForbiddenException.class, () -> AuthContext.requireService(
                context(service(ServiceScopes.SOCIAL_AUDIENCE)), ServiceScopes.NOTIFICATION_INTAKE));
    }

    @Test
    void requireServiceRefusesUsersButLetsUnenforcedAnonymousCallersThrough() {
        assertThrows(ForbiddenException.class, () -> AuthContext.requireService(
                context(new AuthenticatedUser("user_1", "s1")), ServiceScopes.NOTIFICATION_INTAKE));
        assertDoesNotThrow(() -> AuthContext.requireService(context(), ServiceScopes.NOTIFICATION_INTAKE));
    }

    @Test
    void aServiceMayNameAUserOnlyWithTheActScope() {
        assertThrows(ForbiddenException.class,
                () -> AuthContext.requireSelf(context(service(ServiceScopes.SOCIAL_AUDIENCE)), "user_1"));
        assertDoesNotThrow(() -> AuthContext.requireSelf(
                context(service(ServiceScopes.ACT_FOR_USER)), "user_1"));
    }

    @Test
    void selfOrServiceAllowsEitherButNotTheWrongUser() {
        var me = new AuthenticatedUser("user_1", "s1");

        assertDoesNotThrow(() -> AuthContext.requireSelfOrService(context(me), "user_1", ServiceScopes.SOCIAL_AUDIENCE));
        assertThrows(ForbiddenException.class,
                () -> AuthContext.requireSelfOrService(context(me), "user_2", ServiceScopes.SOCIAL_AUDIENCE));
        assertDoesNotThrow(() -> AuthContext.requireSelfOrService(
                context(service(ServiceScopes.SOCIAL_AUDIENCE, ServiceScopes.ACT_FOR_USER)),
                "user_2", ServiceScopes.SOCIAL_AUDIENCE));
        assertThrows(ForbiddenException.class, () -> AuthContext.requireSelfOrService(
                context(service(ServiceScopes.ACT_FOR_USER)), "user_2", ServiceScopes.SOCIAL_AUDIENCE));
    }

    @Test
    void tokenSourceMintsAVerifiableTokenAndCachesIt() {
        var clock = new MutableClock(NOW);
        var source = new ServiceTokenSource("camera", SERVICE_SECRET, Set.of(ServiceScopes.ACT_FOR_USER), clock);

        String first = source.authorization().orElseThrow();
        assertEquals(first, source.authorization().orElseThrow());
        var claims = ServiceTokens.verify(SERVICE_SECRET.getBytes(StandardCharsets.UTF_8),
                first.substring("Bearer ".length()), NOW);
        assertEquals("camera", claims.orElseThrow().service());

        clock.now = NOW.plus(ServiceTokenSource.TTL).minusSeconds(30);
        assertNotEquals(first, source.authorization().orElseThrow(), "refreshes before expiry");
    }

    @Test
    void tokenSourceIsSilentWithoutASecret() {
        assertTrue(new ServiceTokenSource("camera", null, Set.of(), Clock.systemUTC()).authorization().isEmpty());
        assertThrows(IllegalStateException.class,
                () -> new ServiceTokenSource("camera", "short", Set.of(), Clock.systemUTC()));
    }

    private static final class MutableClock extends Clock {
        Instant now;

        MutableClock(Instant now) {
            this.now = now;
        }

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
