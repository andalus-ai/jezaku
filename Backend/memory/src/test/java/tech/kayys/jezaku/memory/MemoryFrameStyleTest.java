package tech.kayys.jezaku.memory;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class MemoryFrameStyleTest {
    @Test
    void noValueMeansTheClientsDefaultLook() {
        assertNull(MemoryFrameStyle.normalize(null));
        assertNull(MemoryFrameStyle.normalize(""));
        assertNull(MemoryFrameStyle.normalize("   "));
    }

    @Test
    void trimsAndLowerCasesAValidId() {
        assertEquals("oak", MemoryFrameStyle.normalize("  Oak "));
        assertEquals("gallery_white", MemoryFrameStyle.normalize("gallery_white"));
    }

    @Test
    void allowsNamespacedExtensionIds() {
        assertEquals("ext.acme.neon-glass", MemoryFrameStyle.normalize("ext.acme.neon-glass"));
    }

    @Test
    void acceptsTheLongestAllowedId() {
        String longest = "a".repeat(MemoryFrameStyle.MAX_LENGTH);
        assertEquals(longest, MemoryFrameStyle.normalize(longest));
    }

    @Test
    void rejectsTooLongIds() {
        assertThrows(BadRequestException.class,
                () -> MemoryFrameStyle.normalize("a".repeat(MemoryFrameStyle.MAX_LENGTH + 1)));
    }

    @Test
    void rejectsIdsThatAreNotSlugs() {
        for (String bad : new String[] {
                "has space", "-leading", ".leading", "semi;colon", "<script>", "../etc", "oak\ngold", "café"}) {
            assertThrows(BadRequestException.class, () -> MemoryFrameStyle.normalize(bad), bad);
        }
    }
}
