package tech.kayys.jezaku.auth;

/**
 * Scopes a service token can carry. A service is granted only the scopes it needs, so a compromised or misconfigured
 * service cannot call endpoints that belong to another integration.
 */
public final class ServiceScopes {
    /** Act for a user the service names (for example camera reading a viewer's minimap). Without this a service
     *  cannot pass a per-user ownership check. */
    public static final String ACT_FOR_USER = "user:act";
    /** Ask the social graph who may see content ({@code /social/audience/*}, {@code /relationships/*}). */
    public static final String SOCIAL_AUDIENCE = "social:audience";
    /** Push media snapshots and lifecycle events into memory. */
    public static final String MEMORY_MEDIA_SYNC = "memory:media-sync";
    /** Hand a delivery to the notification service. */
    public static final String NOTIFICATION_INTAKE = "notification:intake";

    private ServiceScopes() {
    }
}
