package tech.kayys.jezaku.auth;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.container.ContainerRequestContext;

import java.util.Optional;

/** Reads the caller that {@link AuthFilter} established and enforces ownership of a user id. */
public final class AuthContext {
    private AuthContext() {
    }

    public static Optional<AuthenticatedUser> user(ContainerRequestContext context) {
        Object value = context == null ? null : context.getProperty(AuthFilter.USER_PROPERTY);
        return value instanceof AuthenticatedUser user ? Optional.of(user) : Optional.empty();
    }

    /**
     * The user a read should be evaluated for. A caller that names a viewer must be that user; a caller that names
     * none is evaluated as themselves when authenticated, so leaving the parameter out never widens what they see.
     * Anonymous callers (enforcement off) keep whatever they sent.
     */
    public static String viewerOrCaller(ContainerRequestContext context, String claimedViewerId) {
        if (claimedViewerId != null && !claimedViewerId.isBlank()) {
            requireSelf(context, claimedViewerId);
            return claimedViewerId;
        }
        return user(context).map(AuthenticatedUser::userId).orElse(claimedViewerId);
    }

    /**
     * The caller must be {@code userId}. {@link AuthFilter} already rejects anonymous callers whenever authentication
     * is enforced, so an anonymous caller reaching a handler means enforcement is off (dev/test) and existing clients
     * keep working. An authenticated caller can never act as someone else.
     */
    public static void requireSelf(ContainerRequestContext context, String userId) {
        Optional<AuthenticatedUser> user = user(context);
        if (user.isPresent() && !user.get().userId().equals(userId)) {
            throw new ForbiddenException("Not allowed to act for another user");
        }
    }
}
