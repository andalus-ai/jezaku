package tech.kayys.jezaku.auth;

import jakarta.annotation.Priority;
import jakarta.inject.Inject;
import jakarta.ws.rs.NotAuthorizedException;
import jakarta.ws.rs.Priorities;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerRequestFilter;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.Provider;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Authenticates callers from a {@code Authorization: Bearer} access token issued by the identity service.
 *
 * <p>With {@code jezaku.auth.required=false} (the default for dev and test) a valid token is still honoured but
 * anonymous requests pass, so existing clients keep working. Production sets it to {@code true}.
 */
@Provider
@Priority(Priorities.AUTHENTICATION)
public class AuthFilter implements ContainerRequestFilter {
    public static final String USER_PROPERTY = "jezaku.auth.user";

    @ConfigProperty(name = "jezaku.auth.required", defaultValue = "false")
    boolean required;

    @ConfigProperty(name = "jezaku.auth.jwt-secret")
    Optional<String> secret;

    @ConfigProperty(name = "jezaku.auth.public")
    Optional<String> publicRules;

    private volatile AuthPolicy policy;

    @Override
    public void filter(ContainerRequestContext requestContext) {
        String path = "/" + requestContext.getUriInfo().getPath().replaceAll("^/+", "");
        AuthPolicy.Decision decision = policy().decide(
                requestContext.getMethod(),
                path,
                requestContext.getHeaderString(HttpHeaders.AUTHORIZATION),
                Instant.now());
        switch (decision.outcome()) {
            case AUTHENTICATED -> requestContext.setProperty(USER_PROPERTY, decision.user());
            case ALLOWED_ANONYMOUS -> {
                // Anonymous access is allowed here; handlers that need a caller use AuthContext.
            }
            case UNAUTHENTICATED -> throw new NotAuthorizedException(
                    "Authentication required",
                    Response.status(Response.Status.UNAUTHORIZED).header(HttpHeaders.WWW_AUTHENTICATE, "Bearer").build());
        }
    }

    /** {@code jezaku.auth.public} is a comma-separated list of "METHOD /path" rules; empty means the defaults. */
    static List<String> parseRules(String value) {
        return java.util.Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(rule -> !rule.isEmpty())
                .toList();
    }

    private AuthPolicy policy() {
        AuthPolicy current = policy;
        if (current == null) {
            current = new AuthPolicy(required, secret.orElse(null), parseRules(publicRules.orElse("")));
            policy = current;
        }
        return current;
    }
}
