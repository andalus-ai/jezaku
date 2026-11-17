package tech.kayys.jezaku.auth;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Short-lived tokens one Jezaku service presents to another. They are signed with {@code jezaku.auth.service-secret},
 * never the user secret, and carry a different issuer, so a user token can never pass as a service token and a
 * service token can never pass as a user.
 */
public final class ServiceTokens {
    public static final String ISSUER = "jezaku-service";
    /** Verifiers refuse tokens that live longer than this, whatever their {@code exp} says. */
    public static final Duration MAX_LIFETIME = Duration.ofMinutes(10);
    private static final String SECRET_PROPERTY = "jezaku.auth.service-secret";

    private ServiceTokens() {
    }

    public record Claims(String service, Set<String> scopes, Instant issuedAt, Instant expiresAt) {
    }

    public static String issue(byte[] secret, Claims claims) {
        Hs256Codec.requireSecret(secret, SECRET_PROPERTY);
        return Hs256Codec.sign(secret, Map.of(
                "iss", ISSUER,
                "sub", claims.service(),
                "scp", List.copyOf(claims.scopes()),
                "iat", claims.issuedAt().getEpochSecond(),
                "exp", claims.expiresAt().getEpochSecond()));
    }

    public static Optional<Claims> verify(byte[] secret, String token, Instant now) {
        Hs256Codec.requireSecret(secret, SECRET_PROPERTY);
        return Hs256Codec.verifiedPayload(secret, token)
                .filter(payload -> ISSUER.equals(Hs256Codec.text(payload, "iss")))
                .filter(payload -> Hs256Codec.withinLifetime(payload, now))
                .flatMap(ServiceTokens::claims);
    }

    private static Optional<Claims> claims(JsonNode payload) {
        String service = Hs256Codec.text(payload, "sub");
        JsonNode scopeNode = payload.get("scp");
        if (service == null || service.isBlank() || scopeNode == null || !scopeNode.isArray()) {
            return Optional.empty();
        }
        Set<String> scopes = new LinkedHashSet<>();
        for (JsonNode scope : scopeNode) {
            if (!scope.isTextual() || scope.asText().isBlank()) {
                return Optional.empty();
            }
            scopes.add(scope.asText());
        }
        Instant issuedAt = Instant.ofEpochSecond(payload.get("iat").asLong());
        Instant expiresAt = Instant.ofEpochSecond(payload.get("exp").asLong());
        if (Duration.between(issuedAt, expiresAt).compareTo(MAX_LIFETIME) > 0) {
            return Optional.empty();
        }
        return Optional.of(new Claims(service, scopes, issuedAt, expiresAt));
    }
}
