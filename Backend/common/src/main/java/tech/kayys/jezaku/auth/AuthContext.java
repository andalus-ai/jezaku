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

    public static Optional<AuthenticatedService> service(ContainerRequestContext context) {
        Object value = context == null ? null : context.getProperty(AuthFilter.SERVICE_PROPERTY);
        return value instanceof AuthenticatedService service ? Optional.of(service) : Optional.empty();
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
        // A service may name a user only when it was granted that explicitly.
        Optional<AuthenticatedService> service = service(context);
        if (service.isPresent() && !service.get().hasScope(ServiceScopes.ACT_FOR_USER)) {
            throw new ForbiddenException("Service is not allowed to act for a user");
        }
    }

    /**
     * The endpoint is internal: only a service holding {@code scope} may call it. A user token is refused (a user
     * must not reach service-only operations such as media lifecycle events). Anonymous callers reach a handler only
     * while enforcement is off, in which case existing internal calls keep working.
     */
    public static void requireService(ContainerRequestContext context, String scope) {
        if (user(context).isPresent()) {
            throw new ForbiddenException("Internal endpoint");
        }
        Optional<AuthenticatedService> service = service(context);
        if (service.isPresent() && !service.get().hasScope(scope)) {
            throw new ForbiddenException("Service lacks scope " + scope);
        }
    }

    /** A user acting for themselves, or a service holding {@code scope} (and allowed to act for users). */
    public static void requireSelfOrService(ContainerRequestContext context, String userId, String scope) {
        if (service(context).isPresent()) {
            requireService(context, scope);
            requireSelf(context, userId);
        } else {
            requireSelf(context, userId);
        }
    }
}
