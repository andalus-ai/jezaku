package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import jakarta.ws.rs.BadRequestException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdMonetizationPolicyTest {
    @Test
    void normalizesAdVocabularyDefaults() {
        assertEquals("awareness", AdMonetizationPolicy.objective(null));
        assertEquals("traffic", AdMonetizationPolicy.objective("traffic"));
        assertEquals("feed", AdMonetizationPolicy.placement(null));
        assertEquals("camera", AdMonetizationPolicy.placement("camera"));
        assertEquals("impression", AdMonetizationPolicy.eventType(null));
        assertEquals("conversion", AdMonetizationPolicy.eventType("conversion"));
    }

    @Test
    void rejectsInvalidAdVocabulary() {
        assertThrows(BadRequestException.class, () -> AdMonetizationPolicy.objective("install"));
        assertThrows(BadRequestException.class, () -> AdMonetizationPolicy.placement("billboard"));
        assertThrows(BadRequestException.class, () -> AdMonetizationPolicy.eventType("view"));
    }
}
