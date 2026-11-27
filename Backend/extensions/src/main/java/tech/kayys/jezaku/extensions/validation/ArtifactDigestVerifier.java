package tech.kayys.jezaku.extensions.validation;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;

/** Computes and verifies immutable artifact SHA-256 digests. */
public final class ArtifactDigestVerifier {
    private ArtifactDigestVerifier() {}

    public static String sha256(byte[] artifact) {
        if (artifact == null) throw new IllegalArgumentException("artifact must not be null");
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(artifact));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException("SHA-256 is unavailable", impossible);
        }
    }

    public static boolean matchesSha256(byte[] artifact, String expectedHex) {
        if (artifact == null || expectedHex == null || !expectedHex.matches("(?i)^[a-f0-9]{64}$")) return false;
        byte[] expected = HexFormat.of().parseHex(expectedHex.toLowerCase(Locale.ROOT));
        byte[] actual = HexFormat.of().parseHex(sha256(artifact));
        return MessageDigest.isEqual(expected, actual);
    }
}
