package tech.kayys.jezaku.auth;

/**
 * The caller of a request, taken from a verified access token. Possessing a user id (for example in a URL) is
 * never authentication; only a verified token produces one of these.
 */
public record AuthenticatedUser(String userId, String sessionId) {
    public AuthenticatedUser {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("userId is required");
        }
    }
}
