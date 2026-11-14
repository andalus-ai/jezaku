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

    public enum Outcome { ALLOWED_ANONYMOUS, AUTHENTICATED, UNAUTHENTICATED }

    public record Decision(Outcome outcome, AuthenticatedUser user) {
        static Decision anonymous() {
            return new Decision(Outcome.ALLOWED_ANONYMOUS, null);
        }

        static Decision unauthenticated() {
            return new Decision(Outcome.UNAUTHENTICATED, null);
        }
    }

    private final boolean required;
    private final byte[] secret;
    private final List<String> publicRules;

    public AuthPolicy(boolean required, String secret, List<String> publicRules) {
        this.required = required;
        this.secret = secret == null ? null : secret.getBytes(StandardCharsets.UTF_8);
        this.publicRules = publicRules == null || publicRules.isEmpty() ? DEFAULT_PUBLIC : publicRules;
        if (required && (this.secret == null || this.secret.length < JwtTokens.MIN_SECRET_BYTES)) {
            throw new IllegalStateException(
                    "jezaku.auth.required=true needs jezaku.auth.jwt-secret of at least "
                            + JwtTokens.MIN_SECRET_BYTES + " bytes");
        }
    }

    public boolean required() {
        return required;
    }

    public Decision decide(String method, String path, String authorizationHeader, Instant now) {
        Optional<AuthenticatedUser> user = authenticate(authorizationHeader, now);
        if (user.isPresent()) {
            return new Decision(Outcome.AUTHENTICATED, user.get());
        }
        if (!required || "OPTIONS".equalsIgnoreCase(method) || isPublic(method, path)) {
            return Decision.anonymous();
        }
        return Decision.unauthenticated();
    }

    private Optional<AuthenticatedUser> authenticate(String header, Instant now) {
        if (secret == null || secret.length < JwtTokens.MIN_SECRET_BYTES || header == null) {
            return Optional.empty();
        }
        String trimmed = header.trim();
        if (trimmed.length() < 8 || !trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return Optional.empty();
        }
        return JwtTokens.verify(secret, trimmed.substring(7).trim(), now)
                .map(claims -> new AuthenticatedUser(claims.userId(), claims.sessionId()));
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
