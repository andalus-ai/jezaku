package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class CameraSessionSyncLinksBuilderTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void buildsCanonicalFollowUpLinksForThinCapabilitiesAndSelectedSections() {
        CameraSessionEventListResponse events = events(12);
        CameraSessionStreamDescriptor stream = CameraSessionSyncLinksBuilder.streamDescriptor(
                "session",
                events,
                10);
        CameraSessionSyncLinks links = CameraSessionSyncLinksBuilder.links(new CameraSessionSyncLinksBuilder.Request(
                "session",
                80.0,
                25,
                3,
                "people,memories",
                10,
                50,
                CameraSyncContract.CAPABILITIES_MODE_ETAG,
                "client-capabilities",
                CameraSessionSyncSectionSelection.from("freshness,links,clientHints"),
                context(),
                events,
                stream));

        assertEquals(
                "/camera/sessions/session/stream?afterSequence=12&maxEvents=10",
                stream.href());
        assertEquals(
                "/camera/sessions/session/sync?radiusMeters=80.0&limitPerLayer=25"
                        + "&minimapPinLimitPerLayer=3&layers=people%2Cmemories"
                        + "&eventLimit=10&afterSequence=12&contextDeltaLimit=50"
                        + "&capabilitiesMode=etag"
                        + "&capabilitiesEtag=client-capabilities&sections=links%2CclientHints%2Cfreshness",
                links.nextSyncHref());
        assertEquals(
                "/camera/sessions/session/context?radiusMeters=80.0&limitPerLayer=25&layers=people%2Cmemories",
                links.contextHref());
        assertEquals(
                "/camera/sessions/session/minimap?radiusMeters=80.0&limitPerLayer=25"
                        + "&minimapPinLimitPerLayer=3&layers=people%2Cmemories",
                links.minimapHref());
        assertEquals(
                "/camera/sessions/session/minimap/expansion?radiusMeters=80.0&limitPerLayer=25"
                        + "&minimapPinLimitPerLayer=3&layers=people%2Cmemories",
                links.minimapExpansionHref());
        assertEquals(
                "/camera/sessions/session/memories/nearby?radiusMeters=80.0&limitPerLayer=25",
                links.nearbyMemoriesHref());
        assertEquals(
                "/camera/ops/health?viewerId=viewer&lat=-6.8906&lng=107.61098&altitudeMeters=746.2"
                        + "&headingDegrees=90.0&compassDegrees=92.0&speedMetersPerSecond=0.9"
                        + "&radiusMeters=80.0&limitPerLayer=25&layers=people%2Cmemories",
                links.opsHealthHref());
        assertEquals(
                "/camera/sessions/session/events?afterSequence=12&limit=10",
                links.eventsHref());
        assertEquals(stream.href(), links.streamHref());
        assertEquals(CameraSyncContract.CAPABILITIES_HREF, links.capabilitiesHref());
    }

    @Test
    void omitsDefaultCapabilityAndAllSectionQueryKnobs() {
        CameraSessionEventListResponse events = events(4);
        CameraSessionStreamDescriptor stream = CameraSessionSyncLinksBuilder.streamDescriptor(
                "session",
                events,
                50);
        CameraSessionSyncLinks links = CameraSessionSyncLinksBuilder.links(new CameraSessionSyncLinksBuilder.Request(
                "session",
                null,
                25,
                0,
                "people",
                50,
                50,
                CameraSyncContract.CAPABILITIES_MODE_FULL,
                "ignored-for-full-mode",
                CameraSessionSyncSectionSelection.from(null),
                null,
                events,
                stream));

        assertEquals(
                "/camera/sessions/session/sync?limitPerLayer=25&layers=people&eventLimit=50"
                        + "&afterSequence=4&contextDeltaLimit=50",
                links.nextSyncHref());
        assertFalse(links.nextSyncHref().contains("capabilitiesMode"));
        assertFalse(links.nextSyncHref().contains("capabilitiesEtag"));
        assertFalse(links.nextSyncHref().contains("sections"));
        assertEquals(
                "/camera/ops/health?limitPerLayer=25&layers=people",
                links.opsHealthHref());
        assertEquals(
                "/camera/sessions/session/minimap?limitPerLayer=25&layers=people",
                links.minimapHref());
        assertEquals(
                "/camera/sessions/session/minimap/expansion?limitPerLayer=25&layers=people",
                links.minimapExpansionHref());
        assertEquals(
                "/camera/sessions/session/memories/nearby?limitPerLayer=25",
                links.nearbyMemoriesHref());
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

    private CameraContextResponse context() {
        CameraTelemetry telemetry = new CameraTelemetry(
                "viewer",
                new GeoPoint(-6.8906, 107.61098, 746.2),
                90.0,
                92.0,
                92.0,
                0.9,
                null,
                80.0,
                NOW);
        return new CameraContextResponse(
                "viewer",
                telemetry,
                0,
                0,
                null,
                null,
                null,
                null,
                List.of(),
                List.of(),
                NOW);
    }
}
