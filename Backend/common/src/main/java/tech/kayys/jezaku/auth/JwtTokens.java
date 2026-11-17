package tech.kayys.jezaku.auth;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

/**
 * User access tokens shared by the identity service (issuer) and every other service (verifier).
 *
 * <p>Signature handling lives in {@link Hs256Codec}. This class adds the user claims and checks {@code exp},
 * {@code iat}-in-future and the issuer. Revocation is therefore only effective after the (short) token lifetime,
 * which is the usual trade-off for stateless verification.
 */
public final class JwtTokens {
    public static final String ISSUER = "jezaku-identity";
    public static final int MIN_SECRET_BYTES = Hs256Codec.MIN_SECRET_BYTES;
    private static final String SECRET_PROPERTY = "jezaku.auth.jwt-secret";

    private JwtTokens() {
    }

    public record Claims(String userId, String sessionId, Instant issuedAt, Instant expiresAt) {
    }

    public static String issue(byte[] secret, Claims claims) {
        Hs256Codec.requireSecret(secret, SECRET_PROPERTY);
        return Hs256Codec.sign(secret, Map.of(
                "iss", ISSUER,
                "sub", claims.userId(),
                "sid", claims.sessionId(),
                "iat", claims.issuedAt().getEpochSecond(),
                "exp", claims.expiresAt().getEpochSecond()));
    }

    /** Returns the claims when the token is well-formed, correctly signed, unexpired and from this issuer. */
    public static Optional<Claims> verify(byte[] secret, String token, Instant now) {
        Hs256Codec.requireSecret(secret, SECRET_PROPERTY);
        return Hs256Codec.verifiedPayload(secret, token)
                .filter(payload -> ISSUER.equals(Hs256Codec.text(payload, "iss")))
                .filter(payload -> Hs256Codec.withinLifetime(payload, now))
                .flatMap(JwtTokens::claims);
    }

    private static Optional<Claims> claims(JsonNode payload) {
        String userId = Hs256Codec.text(payload, "sub");
        String sessionId = Hs256Codec.text(payload, "sid");
        if (userId == null || userId.isBlank() || sessionId == null || sessionId.isBlank()) {
            return Optional.empty();
        }
        return Optional.of(new Claims(
                userId,
                sessionId,
                Instant.ofEpochSecond(payload.get("iat").asLong()),
                Instant.ofEpochSecond(payload.get("exp").asLong())));
    }
}
