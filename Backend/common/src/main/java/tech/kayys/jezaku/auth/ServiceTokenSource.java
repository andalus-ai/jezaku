package tech.kayys.jezaku.auth;

import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigProvider;

import java.net.http.HttpRequest;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;

/**
 * The caller side of service-to-service auth: mints (and caches) this service's own token and adds it to outgoing
 * requests. With no {@code jezaku.auth.service-secret} configured it adds nothing, so dev, test and the current
 * unenforced deployments behave exactly as before.
 *
 * <p>Config: {@code jezaku.auth.service-name} (falls back to {@code quarkus.application.name}),
 * {@code jezaku.auth.service-secret}, {@code jezaku.auth.service-scopes} (comma separated).
 */
public final class ServiceTokenSource {
    static final Duration TTL = Duration.ofMinutes(5);
    /** Re-mint when less than this remains, so a token never expires mid-flight. */
    private static final Duration REFRESH_MARGIN = Duration.ofSeconds(60);

    private static volatile ServiceTokenSource shared;

    private final String service;
    private final byte[] secret;
    private final Set<String> scopes;
    private final Clock clock;
    private String cachedToken;
    private Instant cachedExpiry = Instant.MIN;

    public ServiceTokenSource(String service, String secret, Set<String> scopes, Clock clock) {
        this.service = service;
        this.secret = secret == null || secret.isBlank() ? null : secret.getBytes(StandardCharsets.UTF_8);
        this.scopes = scopes == null ? Set.of() : Set.copyOf(scopes);
        this.clock = clock;
        if (this.secret != null) {
            Hs256Codec.requireSecret(this.secret, "jezaku.auth.service-secret");
            if (service == null || service.isBlank()) {
                throw new IllegalStateException("jezaku.auth.service-name is required with a service secret");
            }
        }
    }

    /** The process-wide source, built once from configuration. */
    public static ServiceTokenSource shared() {
        ServiceTokenSource current = shared;
        if (current == null) {
            synchronized (ServiceTokenSource.class) {
                current = shared;
                if (current == null) {
                    current = fromConfig(ConfigProvider.getConfig());
                    shared = current;
                }
            }
        }
        return current;
    }

    static ServiceTokenSource fromConfig(Config config) {
        String name = config.getOptionalValue("jezaku.auth.service-name", String.class)
                .or(() -> config.getOptionalValue("quarkus.application.name", String.class))
                .orElse(null);
        String secret = config.getOptionalValue("jezaku.auth.service-secret", String.class).orElse(null);
        Set<String> scopes = new LinkedHashSet<>();
        config.getOptionalValue("jezaku.auth.service-scopes", String.class).ifPresent(value ->
                Arrays.stream(value.split(",")).map(String::trim).filter(s -> !s.isEmpty()).forEach(scopes::add));
        return new ServiceTokenSource(name, secret, scopes, Clock.systemUTC());
    }

    /** {@code Bearer <token>}, or empty when this service has no secret configured. */
    public synchronized Optional<String> authorization() {
        if (secret == null) {
            return Optional.empty();
        }
        Instant now = clock.instant();
        if (cachedToken == null || !now.plus(REFRESH_MARGIN).isBefore(cachedExpiry)) {
            cachedExpiry = now.plus(TTL);
            cachedToken = ServiceTokens.issue(secret, new ServiceTokens.Claims(service, scopes, now, cachedExpiry));
        }
        return Optional.of("Bearer " + cachedToken);
    }

    /** A request builder for {@code uri} that already carries this service's token, if any. */
    public static HttpRequest.Builder request(java.net.URI uri) {
        return shared().authorize(HttpRequest.newBuilder(uri));
    }

    /** Adds the service token to an outgoing request, if there is one. */
    public HttpRequest.Builder authorize(HttpRequest.Builder request) {
        authorization().ifPresent(header -> request.header("Authorization", header));
        return request;
    }
}
