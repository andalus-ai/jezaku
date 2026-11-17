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
 * The HS256 compact-token mechanics shared by user access tokens and service tokens. It knows nothing about what the
 * claims mean: callers supply the payload to sign and interpret the verified payload themselves.
 *
 * <p>Only {@code alg=HS256} is accepted, so {@code none} and algorithm-confusion tokens fail, and the signature is
 * compared in constant time.
 */
final class Hs256Codec {
    static final int MIN_SECRET_BYTES = 32;
    static final Duration CLOCK_SKEW = Duration.ofSeconds(30);
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Base64.Encoder ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder DECODER = Base64.getUrlDecoder();
    private static final String HEADER_JSON = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
    private static final int MAX_TOKEN_LENGTH = 4096;

    private Hs256Codec() {
    }

    static void requireSecret(byte[] secret, String property) {
        if (secret == null || secret.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException(property + " must be at least " + MIN_SECRET_BYTES + " bytes");
        }
    }

    static String sign(byte[] secret, Map<String, Object> payload) {
        String signingInput = encode(HEADER_JSON) + "." + encode(json(payload));
        return signingInput + "." + ENCODER.encodeToString(hmac(secret, signingInput));
    }

    /** The payload when the token is well-formed and correctly signed; claims are not interpreted here. */
    static Optional<JsonNode> verifiedPayload(byte[] secret, String token) {
        if (token == null || token.length() > MAX_TOKEN_LENGTH) {
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
            if (!MessageDigest.isEqual(expected, DECODER.decode(parts[2]))) {
                return Optional.empty();
            }
            return Optional.of(JSON.readTree(DECODER.decode(parts[1])));
        } catch (IllegalArgumentException | java.io.IOException e) {
            return Optional.empty();
        }
    }

    /** True when {@code iat}/{@code exp} are present, the token is unexpired, and not issued in the future. */
    static boolean withinLifetime(JsonNode payload, Instant now) {
        if (!payload.path("iat").canConvertToLong() || !payload.path("exp").canConvertToLong()) {
            return false;
        }
        Instant issuedAt = Instant.ofEpochSecond(payload.get("iat").asLong());
        Instant expiresAt = Instant.ofEpochSecond(payload.get("exp").asLong());
        return now.isBefore(expiresAt) && !issuedAt.isAfter(now.plus(CLOCK_SKEW));
    }

    static String text(JsonNode node, String field) {
        JsonNode value = node.get(field);
        return value != null && value.isTextual() ? value.asText() : null;
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
