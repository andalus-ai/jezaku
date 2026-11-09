package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityReference;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncClientHints;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncFreshness;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncResponse;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;

class CameraSessionSyncResponseProjectorTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void projectsOnlySelectedSections() {
        CameraSessionSyncResponseProjector.Payload payload = payload();

        CameraSessionSyncResponse response = CameraSessionSyncResponseProjector.project(
                CameraSessionSyncSectionSelection.from("links,clientHints,freshness"),
                payload);

        assertNull(response.session());
        assertNull(response.context());
        assertNull(response.events());
        assertNull(response.stream());
        assertSame(payload.links(), response.links());
        assertNull(response.contextDelta());
        assertNull(response.opsHealth());
        assertNull(response.syncPlan());
        assertSame(payload.clientHints(), response.clientHints());
        assertSame(payload.freshness(), response.freshness());
        assertNull(response.capabilitiesRef());
        assertNull(response.capabilities());
        assertNull(response.generatedAt());
    }

    @Test
    void defaultSelectionProjectsEverySection() {
        CameraSessionSyncResponseProjector.Payload payload = payload();

        CameraSessionSyncResponse response = CameraSessionSyncResponseProjector.project(
                CameraSessionSyncSectionSelection.from(null),
                payload);

        assertNotNull(response.session());
        assertNotNull(response.context());
        assertNotNull(response.events());
        assertNotNull(response.stream());
        assertNotNull(response.links());
        assertNotNull(response.contextDelta());
        assertNotNull(response.opsHealth());
        assertNotNull(response.syncPlan());
        assertNotNull(response.clientHints());
        assertNotNull(response.freshness());
        assertNotNull(response.capabilitiesRef());
        assertNotNull(response.capabilities());
        assertNotNull(response.generatedAt());
    }

    private CameraSessionSyncResponseProjector.Payload payload() {
        return new CameraSessionSyncResponseProjector.Payload(
                new CameraSessionResponse(
                        "session",
                        "viewer",
                        "live",
                        true,
                        null,
                        "public",
                        null,
                        100,
                        "",
                        NOW,
                        NOW,
                        NOW.plusSeconds(60)),
                new CameraContextResponse(
                        "viewer",
                        null,
                        0,
                        0,
                        null,
                        null,
                        null,
                        null,
                        List.of(),
                        List.of(),
                        NOW),
                new CameraSessionEventListResponse(
                        "session",
                        0,
                        0,
                        false,
                        List.of(),
                        NOW),
                new CameraSessionStreamDescriptor(
                        "/camera/sessions/session/stream?afterSequence=0&maxEvents=50",
                        "text/event-stream",
                        0,
                        50,
                        CameraSyncContract.STREAM_RETRY_MILLIS),
                new CameraSessionSyncLinks(
                        "/camera/sessions/session/sync",
                        "/camera/sessions/session/context",
                        "/camera/sessions/session/minimap",
                        "/camera/sessions/session/minimap/expansion",
                        "/camera/sessions/session/memories/nearby",
                        "/camera/ops/health",
                        "/camera/sessions/session/events",
                        "/camera/sessions/session/stream",
                        CameraSyncContract.CAPABILITIES_HREF),
                new CameraContextDeltaResponse(
                        "session",
                        "baseline",
                        false,
                        null,
                        0,
                        0,
                        false,
                        0,
                        0,
                        0,
                        0,
                        0,
                        List.of(),
                        NOW),
                new CameraOpsHealthResponse(
                        "healthy",
                        100,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        List.of(),
                        List.of(),
                        List.of(),
                        List.of(),
                        NOW),
                new CameraSessionSyncPlan(
                        15,
                        NOW.plusSeconds(15),
                        15,
                        NOW.plusSeconds(15),
                        60,
                        NOW.plusSeconds(60),
                        5,
                        NOW.plusSeconds(5),
                        false,
                        false,
                        "ambient"),
                new CameraSessionSyncClientHints(
                        false,
                        CameraSyncContract.CAPABILITIES_ETAG,
                        CameraSyncContract.CAPABILITIES_HREF,
                        false,
                        CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE,
                        "/stream",
                        "/stream",
                        "/sync",
                        true,
                        false,
                        true,
                        List.of()),
                new CameraSessionSyncFreshness(
                        NOW,
                        15,
                        NOW.plusSeconds(15),
                        15,
                        NOW.plusSeconds(15),
                        false,
                        false,
                        "ambient"),
                new CameraSessionSyncCapabilityReference(
                        CameraSyncContract.CAPABILITIES_MODE_FULL,
                        CameraSyncContract.CONTRACT_VERSION,
                        CameraSyncContract.CAPABILITIES_CACHE_KEY,
                        CameraSyncContract.CAPABILITIES_ETAG,
                        CameraSyncContract.CAPABILITIES_HREF,
                        true,
                        false,
                        false),
                CameraSessionSyncCapabilityCatalog.current(),
                NOW);
    }
}
