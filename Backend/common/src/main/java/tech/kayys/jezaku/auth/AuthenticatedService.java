package tech.kayys.jezaku.auth;

import java.util.Set;

/** A calling service, taken from a verified service token. Never produced from a user token or a URL. */
public record AuthenticatedService(String name, Set<String> scopes) {
    public AuthenticatedService {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("service name is required");
        }
        scopes = scopes == null ? Set.of() : Set.copyOf(scopes);
    }

    public boolean hasScope(String scope) {
        return scopes.contains(scope);
    }
}
