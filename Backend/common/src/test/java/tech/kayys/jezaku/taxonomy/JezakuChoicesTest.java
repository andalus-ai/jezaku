package tech.kayys.jezaku.taxonomy;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JezakuChoicesTest {
    @Test
    void exposesSharedChoiceSets() {
        assertEquals(4, JezakuChoices.AGE_BANDS.size());
        assertEquals(4, JezakuChoices.PLATFORMS.size());
        assertEquals(3, JezakuChoices.VISIBILITIES.size());
        assertThrows(UnsupportedOperationException.class, () -> JezakuChoices.VISIBILITIES.add("trusted"));
    }
}
