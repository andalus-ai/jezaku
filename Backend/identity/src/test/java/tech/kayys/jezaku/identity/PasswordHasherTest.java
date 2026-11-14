package tech.kayys.jezaku.identity;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PasswordHasherTest {
    @Test
    void hashesAreSaltedAndVerify() {
        String first = PasswordHasher.hash("correct horse battery");
        String second = PasswordHasher.hash("correct horse battery");

        assertNotEquals(first, second);
        assertTrue(first.startsWith("pbkdf2-sha256$600000$"));
        assertTrue(PasswordHasher.verify("correct horse battery", first));
        assertFalse(PasswordHasher.verify("correct horse batterx", first));
        assertFalse(PasswordHasher.needsUpgrade(first));
    }

    @Test
    void legacyHashesStillVerifyAndAreFlaggedForUpgrade() {
        String legacy = PasswordHasher.legacyHash("old-password-1");

        assertTrue(PasswordHasher.verify("old-password-1", legacy));
        assertFalse(PasswordHasher.verify("old-password-2", legacy));
        assertTrue(PasswordHasher.needsUpgrade(legacy));
    }

    @Test
    void cheaperIterationCountsAreFlaggedForUpgrade() {
        String cheap = PasswordHasher.hash("password-1234", 10_000);

        assertTrue(PasswordHasher.verify("password-1234", cheap));
        assertTrue(PasswordHasher.needsUpgrade(cheap));
    }

    @Test
    void malformedValuesNeverVerify() {
        assertFalse(PasswordHasher.verify("x", null));
        assertFalse(PasswordHasher.verify(null, PasswordHasher.hash("x")));
        assertFalse(PasswordHasher.verify("x", ""));
        assertFalse(PasswordHasher.verify("x", "pbkdf2-sha256$abc$AAAA$AAAA"));
        assertFalse(PasswordHasher.verify("x", "pbkdf2-sha256$600000$only-three"));
        assertFalse(PasswordHasher.verify("x", "pbkdf2-sha256$999999999$AAAA$AAAA"));
        assertFalse(PasswordHasher.verify("x", "%%%:%%%"));
        assertTrue(PasswordHasher.needsUpgrade(null));
    }
}
