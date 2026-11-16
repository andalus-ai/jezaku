package tech.kayys.jezaku.social;

import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import tech.kayys.jezaku.auth.AuthContext;

/**
 * Caller checks shared by the social resources. Anonymous callers (authentication not enforced) keep working;
 * an authenticated caller can only act as themselves.
 */
abstract class SocialResourceSupport {
    @Context
    ContainerRequestContext requestContext;

    /** The caller must be {@code userId}. */
    void self(String userId) {
        AuthContext.requireSelf(requestContext, userId);
    }

    /** For an optional field: when the client names a user, it must be the caller. */
    void selfIfPresent(String userId) {
        if (userId != null && !userId.isBlank()) {
            self(userId);
        }
    }

    /** The user a read is evaluated for: the named viewer if it is the caller, else the caller. */
    String viewer(String claimedViewerId) {
        return AuthContext.viewerOrCaller(requestContext, claimedViewerId);
    }
}
