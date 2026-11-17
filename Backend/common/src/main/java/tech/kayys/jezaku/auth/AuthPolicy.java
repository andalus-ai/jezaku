package tech.kayys.jezaku.auth;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Decides whether a request may proceed. Kept free of JAX-RS types so it can be unit-tested directly.
 */
public final class AuthPolicy {
    /** Requests that never need a token: documentation, health, and the calls that create a session. */
    public static final List<String> DEFAULT_PUBLIC = List.of(
            "GET /q/",
            "POST /identity/accounts",
            "POST /identity/sessions",
            // An expired access token is exactly when a client needs to refresh, and validate checks the token it is given.
            "POST /identity/sessions/refresh",
            "GET /identity/sessions/validate");

    private static final int MIN_SERVICE_SECRET_BYTES = Hs256Codec.MIN_SECRET_BYTES;

    /** SERVICE: a verified token from another Jezaku service, not from a user. */
    public enum Outcome { ALLOWED_ANONYMOUS, AUTHENTICATED, SERVICE, UNAUTHENTICATED }

    public record Decision(Outcome outcome, AuthenticatedUser user, AuthenticatedService service) {
        Decision(Outcome outcome, AuthenticatedUser user) {
            this(outcome, user, null);
        }

        static Decision anonymous() {
            return new Decision(Outcome.ALLOWED_ANONYMOUS, null, null);
        }

        static Decision unauthenticated() {
            return new Decision(Outcome.UNAUTHENTICATED, null, null);
        }
    }

    private final boolean required;
    private final byte[] secret;
    private final byte[] serviceSecret;
    private final List<String> publicRules;

    public AuthPolicy(boolean required, String secret, List<String> publicRules) {
        this(required, secret, null, publicRules);
    }

    /**
     * @param serviceSecret signs service-to-service tokens; optional, and when absent service tokens are never
     *                      accepted (internal endpoints then stay reachable only while enforcement is off)
     */
    public AuthPolicy(boolean required, String secret, String serviceSecret, List<String> publicRules) {
        this.required = required;
        this.secret = secret == null ? null : secret.getBytes(StandardCharsets.UTF_8);
        this.serviceSecret = serviceSecret == null || serviceSecret.isBlank()
                ? null : serviceSecret.getBytes(StandardCharsets.UTF_8);
        this.publicRules = publicRules == null || publicRules.isEmpty() ? DEFAULT_PUBLIC : publicRules;
        if (required && (this.secret == null || this.secret.length < JwtTokens.MIN_SECRET_BYTES)) {
            throw new IllegalStateException(
                    "jezaku.auth.required=true needs jezaku.auth.jwt-secret of at least "
                            + JwtTokens.MIN_SECRET_BYTES + " bytes");
        }
        if (this.serviceSecret != null && this.serviceSecret.length < MIN_SERVICE_SECRET_BYTES) {
            throw new IllegalStateException(
                    "jezaku.auth.service-secret must be at least " + MIN_SERVICE_SECRET_BYTES + " bytes");
        }
        if (this.serviceSecret != null && this.secret != null && java.util.Arrays.equals(this.serviceSecret, this.secret)) {
            throw new IllegalStateException(
                    "jezaku.auth.service-secret must differ from jezaku.auth.jwt-secret");
        }
    }

    public boolean required() {
        return required;
    }

    public Decision decide(String method, String path, String authorizationHeader, Instant now) {
        String token = bearerToken(authorizationHeader);
        Optional<AuthenticatedUser> user = authenticateUser(token, now);
        if (user.isPresent()) {
            return new Decision(Outcome.AUTHENTICATED, user.get(), null);
        }
        Optional<AuthenticatedService> service = authenticateService(token, now);
        if (service.isPresent()) {
            return new Decision(Outcome.SERVICE, null, service.get());
        }
        if (!required || "OPTIONS".equalsIgnoreCase(method) || isPublic(method, path)) {
            return Decision.anonymous();
        }
        return Decision.unauthenticated();
    }

    private static String bearerToken(String header) {
        if (header == null) {
            return null;
        }
        String trimmed = header.trim();
        if (trimmed.length() < 8 || !trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return null;
        }
        return trimmed.substring(7).trim();
    }

    private Optional<AuthenticatedUser> authenticateUser(String token, Instant now) {
        if (token == null || secret == null || secret.length < JwtTokens.MIN_SECRET_BYTES) {
            return Optional.empty();
        }
        return JwtTokens.verify(secret, token, now)
                .map(claims -> new AuthenticatedUser(claims.userId(), claims.sessionId()));
    }

    private Optional<AuthenticatedService> authenticateService(String token, Instant now) {
        if (token == null || serviceSecret == null) {
            return Optional.empty();
        }
        return ServiceTokens.verify(serviceSecret, token, now)
                .map(claims -> new AuthenticatedService(claims.service(), claims.scopes()));
    }

    private boolean isPublic(String method, String path) {
        String normalizedMethod = method == null ? "" : method.toUpperCase(Locale.ROOT);
        String normalizedPath = path == null ? "" : path;
        for (String rule : publicRules) {
            int space = rule.indexOf(' ');
            if (space < 0) {
                continue;
            }
            String ruleMethod = rule.substring(0, space);
            String rulePath = rule.substring(space + 1);
            if (!ruleMethod.equals(normalizedMethod)) {
                continue;
            }
            // A trailing slash means "this prefix"; otherwise the path must match exactly.
            if (rulePath.endsWith("/") ? normalizedPath.startsWith(rulePath) : normalizedPath.equals(rulePath)) {
                return true;
            }
        }
        return false;
    }
}
