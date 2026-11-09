package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertSame;

class CameraSessionSyncRequestTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void suppliesContractDefaultsForMissingOptionalLimits() {
        CameraSessionSyncRequest request = CameraSessionSyncRequest.fromRaw(
                "session",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null);

        assertEquals(CameraSyncContract.DEFAULT_EVENT_LIMIT, request.eventLimit());
        assertEquals(CameraSyncContract.DEFAULT_CURSOR, request.afterSequence());
        assertEquals(CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT, request.contextDeltaLimit());
        assertEquals(
                CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                request.minimapPinLimitPerLayer());
    }

    @Test
    void createsLinkBuilderRequestWithoutRepeatingSyncQueryKnobs() {
        CameraSessionSyncRequest request = CameraSessionSyncRequest.fromRaw(
                "session",
                80.0,
                25,
                3,
                "people",
                10,
                5L,
                30,
                "etag",
                "client-capabilities",
                "links");
        CameraSessionSyncSectionSelection sectionSelection = CameraSessionSyncSectionSelection.from("links");
        CameraSessionEventListResponse events = new CameraSessionEventListResponse(
                "session",
                0,
                12,
                false,
                List.of(),
                NOW);
        CameraSessionStreamDescriptor stream = CameraSessionSyncLinksBuilder.streamDescriptor(
                "session",
                events,
                request.eventLimit());

        CameraSessionSyncLinksBuilder.Request linksRequest = request.linksRequest(
                CameraSyncContract.CAPABILITIES_MODE_ETAG,
                sectionSelection,
                null,
                events,
                stream);

        assertEquals("session", linksRequest.sessionId());
        assertEquals(80.0, linksRequest.radiusMeters());
        assertEquals(25, linksRequest.limitPerLayer());
        assertEquals(3, linksRequest.minimapPinLimitPerLayer());
        assertEquals("people", linksRequest.layers());
        assertEquals(10, linksRequest.eventLimit());
        assertEquals(30, linksRequest.contextDeltaLimit());
        assertEquals(CameraSyncContract.CAPABILITIES_MODE_ETAG, linksRequest.capabilitiesMode());
        assertEquals("client-capabilities", linksRequest.capabilitiesEtag());
        assertSame(sectionSelection, linksRequest.sectionSelection());
        assertSame(events, linksRequest.events());
        assertSame(stream, linksRequest.stream());
    }

    @Test
    void rejectsOutOfRangeSyncLimitsBeforeBuildingDerivedState() {
        assertThrows(
                BadRequestException.class,
                () -> CameraSessionSyncRequest.fromRaw(
                        "session",
                        null,
                        null,
                        null,
                        null,
                        CameraSyncContract.MAX_EVENT_LIMIT + 1,
                        null,
                        null,
                        null,
                        null,
                        null).eventLimit());
        assertThrows(
                BadRequestException.class,
                () -> CameraSessionSyncRequest.fromRaw(
                        "session",
                        null,
                        null,
                        null,
                        null,
                        null,
                        -1L,
                        null,
                        null,
                        null,
                        null).afterSequence());
        assertThrows(
                BadRequestException.class,
                () -> CameraSessionSyncRequest.fromRaw(
                        "session",
                        null,
                        null,
                        null,
                        null,
                        null,
                        null,
                        CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT + 1,
                        null,
                        null,
                        null).contextDeltaLimit());
        assertThrows(
                BadRequestException.class,
                () -> CameraSessionSyncRequest.fromRaw(
                        "session",
                        null,
                        null,
                        CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER + 1,
                        null,
                        null,
                        null,
                        null,
                        null,
                        null,
                        null).minimapPinLimitPerLayer());
    }

    @Test
    void canonicalConstructorAlsoRejectsInvalidNormalizedValues() {
        assertThrows(
                BadRequestException.class,
                () -> new CameraSessionSyncRequest(
                        "session",
                        null,
                        null,
                        CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                        null,
                        CameraSyncContract.MIN_EVENT_LIMIT - 1,
                        0,
                        CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT,
                        null,
                        null,
                        null));
    }
}
