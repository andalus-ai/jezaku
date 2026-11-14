package tech.kayys.jezaku.identity;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.spec.InvalidKeySpecException;
import java.util.Base64;

/**
 * PBKDF2-HMAC-SHA256 password hashing with a self-describing format so the cost can be raised later.
 *
 * <p>Current format: {@code pbkdf2-sha256$<iterations>$<salt>$<hash>}. The legacy {@code salt:hash} format (16,000
 * iterations) still verifies, and {@link #needsUpgrade} tells the caller to re-hash after a successful login.
 */
final class PasswordHasher {
    /** OWASP's 2023 minimum for PBKDF2-HMAC-SHA256. */
    static final int ITERATIONS = 600_000;
    static final int LEGACY_ITERATIONS = 16_000;
    private static final int KEY_BITS = 256;
    private static final String FORMAT = "pbkdf2-sha256";
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final String DUMMY_HASH = hash("not-a-real-password");

    private PasswordHasher() {
    }

    static String hash(String password) {
        return hash(password, ITERATIONS);
    }

    static String hash(String password, int iterations) {
        byte[] salt = new byte[16];
        RANDOM.nextBytes(salt);
        byte[] hash = pbkdf2(password, salt, iterations);
        return FORMAT + "$" + iterations + "$"
                + Base64.getEncoder().encodeToString(salt) + "$" + Base64.getEncoder().encodeToString(hash);
    }

    /** Legacy {@code salt:hash} value, as written before the format was versioned. Used by tests and migrations. */
    static String legacyHash(String password) {
        byte[] salt = new byte[16];
        RANDOM.nextBytes(salt);
        byte[] hash = pbkdf2(password, salt, LEGACY_ITERATIONS);
        return Base64.getEncoder().encodeToString(salt) + ":" + Base64.getEncoder().encodeToString(hash);
    }

    static boolean verify(String password, String encoded) {
        if (password == null || encoded == null) {
            return false;
        }
        try {
            int iterations;
            String saltPart;
            String hashPart;
            if (encoded.startsWith(FORMAT + "$")) {
                String[] parts = encoded.split("\\$", 4);
                if (parts.length != 4) {
                    return false;
                }
                iterations = Integer.parseInt(parts[1]);
                saltPart = parts[2];
                hashPart = parts[3];
            } else if (encoded.contains(":")) {
                String[] parts = encoded.split(":", 2);
                iterations = LEGACY_ITERATIONS;
                saltPart = parts[0];
                hashPart = parts[1];
            } else {
                return false;
            }
            if (iterations < 1 || iterations > 10_000_000) {
                return false;
            }
            byte[] salt = Base64.getDecoder().decode(saltPart);
            byte[] expected = Base64.getDecoder().decode(hashPart);
            return MessageDigest.isEqual(expected, pbkdf2(password, salt, iterations));
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    static boolean needsUpgrade(String encoded) {
        return encoded == null || !encoded.startsWith(FORMAT + "$" + ITERATIONS + "$");
    }

    /** Burns the same work as a real check so unknown identifiers are not distinguishable by response time. */
    static void verifyAgainstDummy(String password) {
        verify(password, DUMMY_HASH);
    }

    private static byte[] pbkdf2(String password, byte[] salt, int iterations) {
        try {
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, KEY_BITS);
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } catch (InvalidKeySpecException | NoSuchAlgorithmException e) {
            throw new IllegalStateException("Unable to hash password", e);
        }
    }
}
