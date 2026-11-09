package tech.kayys.jezaku.presence;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceAudienceAccessHealth;

import java.util.List;
import java.util.Locale;
import java.util.Optional;

@ApplicationScoped
class DefaultPresenceAudienceAccessClient implements PresenceAudienceAccessClient {
    private final LocalPresenceAudienceAccessClient localClient = new LocalPresenceAudienceAccessClient();

    @Inject
    ObjectMapper objectMapper;

    @ConfigProperty(name = "jezaku.presence.audience-access.source", defaultValue = "local")
    String source;

    @ConfigProperty(name = "jezaku.presence.audience-access.social-base-url")
    Optional<String> socialBaseUrl;

    @ConfigProperty(name = "jezaku.presence.audience-access.request-timeout-seconds", defaultValue = "3")
    int requestTimeoutSeconds;

    @ConfigProperty(name = "jezaku.presence.audience-access.fallback-to-local", defaultValue = "true")
    boolean fallbackToLocal;

    @Override
    public PresenceAudienceAccessResponse access(PresenceAudienceAccessRequest request) {
        return switch (normalizedSource()) {
            case "local" -> localClient.access(request);
            case "http", "social" -> httpAccess(request);
            default -> throw new IllegalStateException("Unsupported presence audience access source: " + source);
        };
    }

    @Override
    public PresenceAudienceAccessHealth health() {
        String requested = normalizedSource();
        if ("local".equals(requested)) {
            return localClient.health();
        }
        if (!"http".equals(requested) && !"social".equals(requested)) {
            return new PresenceAudienceAccessHealth(
                    requested,
                    "none",
                    "critical",
                    false,
                    configuredSocialBaseUrl(),
                    fallbackToLocal,
                    List.of("unsupported_audience_access_source"),
                    List.of("set_jezaku_presence_audience_access_source_to_local_or_http"));
        }
        if (configuredSocialBaseUrl()) {
            return new PresenceAudienceAccessHealth(
                    requested,
                    "social",
                    "healthy",
                    true,
                    true,
                    fallbackToLocal,
                    List.of(),
                    List.of());
        }
        if (fallbackToLocal) {
            return new PresenceAudienceAccessHealth(
                    requested,
                    "local",
                    "degraded",
                    true,
                    false,
                    true,
                    List.of("social_base_url_missing", "fallback_to_local_active"),
                    List.of("configure_jezaku_presence_audience_access_social_base_url"));
        }
        return new PresenceAudienceAccessHealth(
                requested,
                "none",
                "critical",
                false,
                false,
                false,
                List.of("social_base_url_missing"),
                List.of("configure_jezaku_presence_audience_access_social_base_url"));
    }

    private PresenceAudienceAccessResponse httpAccess(PresenceAudienceAccessRequest request) {
        if (request.viewerId().isBlank()) {
            return localClient.access(request);
        }
        try {
            return new HttpPresenceAudienceAccessClient(objectMapper, socialBaseUrl, requestTimeoutSeconds)
                    .access(request);
        } catch (RuntimeException exception) {
            if (!fallbackToLocal) {
                throw exception;
            }
            return localClient.access(request).withSource("local", true);
        }
    }

    private String normalizedSource() {
        return source == null || source.isBlank()
                ? "local"
                : source.trim().toLowerCase(Locale.ROOT);
    }

    private boolean configuredSocialBaseUrl() {
        return socialBaseUrl
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .isPresent();
    }
}
