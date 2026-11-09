package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.ForbiddenException;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.Optional;

@ApplicationScoped
public class MessagingOpsGuard {
    public static final String OPS_TOKEN_HEADER = "X-Jezaku-Ops-Token";

    @ConfigProperty(name = "jezaku.messaging.ops-token")
    Optional<String> opsToken;

    public void requireAccess(String providedToken) {
        Optional<String> configuredToken = opsToken
                .map(String::trim)
                .filter(value -> !value.isEmpty());
        if (configuredToken.isEmpty()) {
            return;
        }
        String candidate = providedToken == null ? "" : providedToken.trim();
        if (!configuredToken.get().equals(candidate)) {
            throw new ForbiddenException("Messaging ops token is invalid");
        }
    }
}
