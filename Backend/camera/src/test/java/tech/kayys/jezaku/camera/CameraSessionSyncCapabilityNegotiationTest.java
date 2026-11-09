package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncCapabilityNegotiationTest {
    @Test
    void defaultsToFullModeAndEmbedsCapabilitiesForDefaultSections() {
        CameraSessionSyncCapabilityNegotiation negotiation = CameraSessionSyncCapabilityNegotiation.from(
                null,
                null,
                CameraSessionSyncSectionSelection.from(null));

        assertEquals(CameraSyncContract.CAPABILITIES_MODE_FULL, negotiation.mode());
        assertNotNull(negotiation.capabilities());
        assertTrue(negotiation.reference().included());
        assertFalse(negotiation.reference().clientCacheFresh());
        assertFalse(negotiation.reference().refreshRecommended());
    }

    @Test
    void fullModeDoesNotEmbedCapabilitiesWhenCapabilitiesSectionIsUnselected() {
        CameraSessionSyncCapabilityNegotiation negotiation = CameraSessionSyncCapabilityNegotiation.from(
                " FULL ",
                null,
                CameraSessionSyncSectionSelection.from("capabilitiesRef"));

        assertEquals(CameraSyncContract.CAPABILITIES_MODE_FULL, negotiation.mode());
        assertNull(negotiation.capabilities());
        assertFalse(negotiation.reference().included());
        assertTrue(negotiation.reference().refreshRecommended());
    }

    @Test
    void etagModeNeverEmbedsCapabilitiesAndRefreshesStaleClients() {
        CameraSessionSyncCapabilityNegotiation negotiation = CameraSessionSyncCapabilityNegotiation.from(
                "etag",
                "camera-sync.v1.capabilities.r3",
                CameraSessionSyncSectionSelection.from(null));

        assertEquals(CameraSyncContract.CAPABILITIES_MODE_ETAG, negotiation.mode());
        assertNull(negotiation.capabilities());
        assertFalse(negotiation.reference().included());
        assertFalse(negotiation.reference().clientCacheFresh());
        assertTrue(negotiation.reference().refreshRecommended());
    }

    @Test
    void etagModeRecognizesFreshHttpEtag() {
        CameraSessionSyncCapabilityNegotiation negotiation = CameraSessionSyncCapabilityNegotiation.from(
                "etag",
                CameraSessionSyncCapabilityCatalog.httpEtag(),
                CameraSessionSyncSectionSelection.from(null));

        assertNull(negotiation.capabilities());
        assertTrue(negotiation.reference().clientCacheFresh());
        assertFalse(negotiation.reference().refreshRecommended());
    }

    @Test
    void rejectsUnsupportedCapabilitiesMode() {
        assertThrows(
                BadRequestException.class,
                () -> CameraSessionSyncCapabilityNegotiation.from(
                        "inline",
                        null,
                        CameraSessionSyncSectionSelection.from(null)));
    }
}
