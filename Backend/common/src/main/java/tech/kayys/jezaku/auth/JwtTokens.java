package tech.kayys.jezaku.auth;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;

/**
 * Minimal HS256 access tokens shared by the identity service (issuer) and every other service (verifier).
 *
 * <p>Only {@code alg=HS256} is accepted, so {@code none} and algorithm-confusion tokens fail. The signature is compared
 * in constant time and {@code exp}, {@code iat}-in-future and the issuer are checked. Revocation is therefore only
 * effective after the (short) token lifetime, which is the usual trade-off for stateless verification.
 */
public final class JwtTokens {
    public static final String ISSUER = "jezaku-identity";
    public static final int MIN_SECRET_BYTES = 32;
    private static final Duration CLOCK_SKEW = Duration.ofSeconds(30);
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Base64.Encoder ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder DECODER = Base64.getUrlDecoder();
    private static final String HEADER_JSON = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";

    private JwtTokens() {
    }

    public record Claims(String userId, String sessionId, Instant issuedAt, Instant expiresAt) {
    }

    public static String issue(byte[] secret, Claims claims) {
        requireSecret(secret);
        String payload = json(Map.of(
                "iss", ISSUER,
                "sub", claims.userId(),
                "sid", claims.sessionId(),
                "iat", claims.issuedAt().getEpochSecond(),
                "exp", claims.expiresAt().getEpochSecond()));
        String signingInput = encode(HEADER_JSON) + "." + encode(payload);
        return signingInput + "." + ENCODER.encodeToString(hmac(secret, signingInput));
    }

    /** Returns the claims when the token is well-formed, correctly signed, unexpired and from this issuer. */
    public static Optional<Claims> verify(byte[] secret, String token, Instant now) {
        requireSecret(secret);
        if (token == null || token.length() > 4096) {
            return Optional.empty();
        }
        String[] parts = token.split("\\.", -1);
        if (parts.length != 3) {
            return Optional.empty();
        }
        try {
            JsonNode header = JSON.readTree(DECODER.decode(parts[0]));
            if (!"HS256".equals(text(header, "alg"))) {
                return Optional.empty();
            }
            byte[] expected = hmac(secret, parts[0] + "." + parts[1]);
            byte[] actual = DECODER.decode(parts[2]);
            if (!MessageDigest.isEqual(expected, actual)) {
                return Optional.empty();
            }
            JsonNode payload = JSON.readTree(DECODER.decode(parts[1]));
            if (!ISSUER.equals(text(payload, "iss"))) {
                return Optional.empty();
            }
            String userId = text(payload, "sub");
            String sessionId = text(payload, "sid");
            if (userId == null || userId.isBlank() || sessionId == null || sessionId.isBlank()
                    || !payload.path("iat").canConvertToLong() || !payload.path("exp").canConvertToLong()) {
                return Optional.empty();
            }
            Instant issuedAt = Instant.ofEpochSecond(payload.get("iat").asLong());
            Instant expiresAt = Instant.ofEpochSecond(payload.get("exp").asLong());
            if (!now.isBefore(expiresAt) || issuedAt.isAfter(now.plus(CLOCK_SKEW))) {
                return Optional.empty();
            }
            return Optional.of(new Claims(userId, sessionId, issuedAt, expiresAt));
        } catch (IllegalArgumentException | java.io.IOException e) {
            return Optional.empty();
        }
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node.get(field);
        return value != null && value.isTextual() ? value.asText() : null;
    }

    private static void requireSecret(byte[] secret) {
        if (secret == null || secret.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException(
                    "jezaku.auth.jwt-secret must be at least " + MIN_SECRET_BYTES + " bytes");
        }
    }

    private static String json(Map<String, Object> values) {
        try {
            return JSON.writeValueAsString(values);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Unable to encode token", e);
        }
    }

    private static String encode(String value) {
        return ENCODER.encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }

    private static byte[] hmac(byte[] secret, String input) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return mac.doFinal(input.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HMAC unavailable", e);
        }
    }
}
