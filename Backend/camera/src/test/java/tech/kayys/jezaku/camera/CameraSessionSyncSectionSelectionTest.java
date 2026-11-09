package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncSectionSelectionTest {
    @Test
    void defaultsToAllSections() {
        CameraSessionSyncSectionSelection selection = CameraSessionSyncSectionSelection.from(null);

        assertTrue(selection.allSections());
        assertEquals(CameraSyncContract.SUPPORTED_SYNC_RESPONSE_SECTIONS, selection.sections());
        assertNull(selection.queryValue());
    }

    @Test
    void canonicalizesRequestedSectionsInContractOrder() {
        CameraSessionSyncSectionSelection selection = CameraSessionSyncSectionSelection.from(
                "clientHints, freshness, links, clientHints");

        assertEquals(List.of("links", "clientHints", "freshness"), selection.sections());
        assertEquals("links,clientHints,freshness", selection.queryValue());
        assertTrue(selection.includes(CameraSyncContract.SYNC_SECTION_CLIENT_HINTS));
    }

    @Test
    void rejectsUnknownSections() {
        assertThrows(
                BadRequestException.class,
                () -> CameraSessionSyncSectionSelection.from("clientHints,unknown"));
    }
}
