package tech.kayys.jezaku.extensions.validation;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ArtifactDigestVerifierTest {
    @Test
    void calculatesKnownSha256Digest() {
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                ArtifactDigestVerifier.sha256("abc".getBytes()));
    }

    @Test
    void matchesDigestCaseInsensitively() {
        byte[] artifact = "jezaku-extension".getBytes();
        assertTrue(ArtifactDigestVerifier.matchesSha256(artifact, ArtifactDigestVerifier.sha256(artifact).toUpperCase()));
    }

    @Test
    void rejectsMalformedOrMismatchedDigest() {
        assertFalse(ArtifactDigestVerifier.matchesSha256("a".getBytes(), "not-a-digest"));
        assertFalse(ArtifactDigestVerifier.matchesSha256("a".getBytes(), "0".repeat(64)));
        assertFalse(ArtifactDigestVerifier.matchesSha256(null, "0".repeat(64)));
    }
}
