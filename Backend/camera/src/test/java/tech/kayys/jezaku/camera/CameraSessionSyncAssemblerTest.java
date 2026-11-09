package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncAssemblerTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void linkOnlyAssemblySkipsHeavyDerivedBlocks() {
        CameraSessionSyncAssembler assembler = new CameraSessionSyncAssembler();
        assembler.contextDeltas = new CameraContextDeltaService();
        CameraSessionSyncRequest request = CameraSessionSyncRequest.fromRaw(
                "session",
                80.0,
                25,
                0,
                "people",
                10,
                0L,
                30,
                CameraSyncContract.CAPABILITIES_MODE_FULL,
                null,
                "links");
        CameraSessionSyncSectionSelection sectionSelection = CameraSessionSyncSectionSelection.from("links");
        CameraSessionSyncCapabilityNegotiation capabilities = CameraSessionSyncCapabilityNegotiation.from(
                request.capabilitiesMode(),
                request.capabilitiesEtag(),
                sectionSelection);

        CameraSessionSyncResponse response = assembler.assemble(
                request,
                capabilities,
                sectionSelection,
                null,
                null,
                events(12));

        assertNotNull(response.links());
        assertTrue(response.links().nextSyncHref().contains("sections=links"));
        assertNull(response.session());
        assertNull(response.context());
        assertNull(response.events());
        assertNull(response.stream());
        assertNull(response.contextDelta());
        assertNull(response.opsHealth());
        assertNull(response.syncPlan());
        assertNull(response.clientHints());
        assertNull(response.freshness());
        assertNull(response.capabilitiesRef());
        assertNull(response.capabilities());
        assertNull(response.generatedAt());
    }

    private CameraSessionEventListResponse events(long lastSequence) {
        return new CameraSessionEventListResponse(
                "session",
                0,
                lastSequence,
                false,
                List.of(),
                NOW);
    }
}
