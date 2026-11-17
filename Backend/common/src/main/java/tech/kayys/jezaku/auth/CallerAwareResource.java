package tech.kayys.jezaku.auth;

import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;

/**
 * Base class for REST resources that bind actions to the authenticated caller. Anonymous callers (authentication not
 * enforced, dev/test) keep working; an authenticated caller can only act as themselves.
 */
public abstract class CallerAwareResource {
    @Context
    protected ContainerRequestContext requestContext;

    /** The caller must be {@code userId}. */
    protected void self(String userId) {
        AuthContext.requireSelf(requestContext, userId);
    }

    /** For an optional field: when the client names a user, it must be the caller. */
    protected void selfIfPresent(String userId) {
        if (userId != null && !userId.isBlank()) {
            self(userId);
        }
    }

    /** The user a read is evaluated for: the named viewer if it is the caller, else the caller. */
    protected String viewer(String claimedViewerId) {
        return AuthContext.viewerOrCaller(requestContext, claimedViewerId);
    }

    /** The endpoint is internal: only a service holding {@code scope} may call it. */
    protected void requireService(String scope) {
        AuthContext.requireService(requestContext, scope);
    }

    /** The user acting for themselves, or a service that holds {@code scope} and may act for users. */
    protected void selfOrService(String userId, String scope) {
        AuthContext.requireSelfOrService(requestContext, userId, scope);
    }
}
