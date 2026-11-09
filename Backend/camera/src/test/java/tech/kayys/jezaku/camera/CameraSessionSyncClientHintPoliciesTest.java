package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimap;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityReference;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncClientHints;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncClientHintPoliciesTest {
    private static final Instant NOW = Instant.parse("2026-06-03T00:00:00Z");

    @Test
    void prefersEventStreamWhenSyncIsHealthyAndStreamExists() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, "ambient"),
                opsHealth("healthy"),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertFalse(hints.refreshCapabilities());
        assertFalse(hints.useCachedCapabilities());
        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE, hints.preferredNextTransport());
        assertEquals("/camera/sessions/session/stream?afterSequence=10", hints.preferredNextHref());
        assertTrue(hints.openEventStream());
        assertFalse(hints.pollRecommended());
        assertTrue(hints.offlineSafe());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_INCLUDED));
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE));
    }

    @Test
    void recommendsPollingWhenBacklogNeedsCatchUp() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(false, true, false),
                plan(true, false, CameraSyncContract.SYNC_REASON_EVENT_BACKLOG),
                opsHealth("healthy"),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertFalse(hints.refreshCapabilities());
        assertTrue(hints.useCachedCapabilities());
        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC, hints.preferredNextTransport());
        assertEquals("/camera/sessions/session/sync?afterSequence=10", hints.preferredNextHref());
        assertFalse(hints.openEventStream());
        assertTrue(hints.pollRecommended());
        assertTrue(hints.offlineSafe());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_CACHE_FRESH));
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE));
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_SYNC_BACKLOG));
    }

    @Test
    void recommendsPollingWhenOpsHealthNeedsAttention() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, CameraSyncContract.SYNC_REASON_OPS_HEALTH_DEGRADED),
                opsHealth("degraded"),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC, hints.preferredNextTransport());
        assertEquals("/camera/sessions/session/sync?afterSequence=10", hints.preferredNextHref());
        assertFalse(hints.openEventStream());
        assertTrue(hints.pollRecommended());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_OPS_HEALTH_ATTENTION));
    }

    @Test
    void includesSpecificReasonWhenVisibilityAudienceNeedsAttention() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, CameraSyncContract.SYNC_REASON_OPS_HEALTH_DEGRADED),
                opsHealth("degraded", List.of("visibility_audience_fallback")),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC, hints.preferredNextTransport());
        assertTrue(hints.pollRecommended());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_OPS_HEALTH_ATTENTION));
        assertTrue(hints.reasons().contains(
                CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION));
    }

    @Test
    void includesVisibilityPressureReasonFromContextWithoutForcingPolling() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, "ambient"),
                opsHealth("healthy"),
                context(3, 0),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE, hints.preferredNextTransport());
        assertTrue(hints.openEventStream());
        assertFalse(hints.pollRecommended());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_PRESSURE));
    }

    @Test
    void includesMinimapClippedReasonWithoutForcingPolling() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, "ambient"),
                opsHealth("healthy"),
                context(0, 0, true),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE, hints.preferredNextTransport());
        assertTrue(hints.openEventStream());
        assertFalse(hints.pollRecommended());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_MINIMAP_CLIPPED));
    }

    @Test
    void recommendsPollingWhenContextVisibilityAudienceNeedsAttention() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, "ambient"),
                null,
                context(0, 1),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC, hints.preferredNextTransport());
        assertFalse(hints.openEventStream());
        assertTrue(hints.pollRecommended());
        assertTrue(hints.reasons().contains(
                CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION));
    }

    @Test
    void asksClientToRefreshStaleCapabilitiesWithoutTrustingOfflineRender() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(false, false, true),
                plan(false, false, "ambient"),
                opsHealth("healthy"),
                links(
                        "/camera/sessions/session/sync?afterSequence=10",
                        "/camera/sessions/session/stream?afterSequence=10"));

        assertTrue(hints.refreshCapabilities());
        assertFalse(hints.useCachedCapabilities());
        assertEquals(CameraSyncContract.CAPABILITIES_ETAG, hints.capabilitiesEtag());
        assertEquals(CameraSyncContract.CAPABILITIES_HREF, hints.capabilitiesHref());
        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE, hints.preferredNextTransport());
        assertTrue(hints.openEventStream());
        assertFalse(hints.pollRecommended());
        assertFalse(hints.offlineSafe());
        assertTrue(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_REFRESH_RECOMMENDED));
    }

    @Test
    void fallsBackToPollingWhenStreamHrefIsMissing() {
        CameraSessionSyncClientHints hints = CameraSessionSyncClientHintPolicies.from(
                capabilities(true, false, false),
                plan(false, false, "ambient"),
                opsHealth("healthy"),
                links("/camera/sessions/session/sync?afterSequence=10", null));

        assertEquals(CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC, hints.preferredNextTransport());
        assertEquals("/camera/sessions/session/sync?afterSequence=10", hints.preferredNextHref());
        assertFalse(hints.openEventStream());
        assertTrue(hints.pollRecommended());
        assertFalse(hints.reasons().contains(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE));
    }

    private CameraSessionSyncCapabilityReference capabilities(
            boolean included,
            boolean clientCacheFresh,
            boolean refreshRecommended) {
        return new CameraSessionSyncCapabilityReference(
                included ? CameraSyncContract.CAPABILITIES_MODE_FULL : CameraSyncContract.CAPABILITIES_MODE_ETAG,
                CameraSyncContract.CONTRACT_VERSION,
                CameraSyncContract.CAPABILITIES_CACHE_KEY,
                CameraSyncContract.CAPABILITIES_ETAG,
                CameraSyncContract.CAPABILITIES_HREF,
                included,
                clientCacheFresh,
                refreshRecommended);
    }

    private CameraSessionSyncPlan plan(boolean eventBacklog, boolean deltaBacklog, String reason) {
        return new CameraSessionSyncPlan(
                eventBacklog || deltaBacklog ? 1 : 15,
                NOW.plusSeconds(eventBacklog || deltaBacklog ? 1 : 15),
                15,
                NOW.plusSeconds(15),
                60,
                NOW.plusSeconds(60),
                5,
                NOW.plusSeconds(5),
                eventBacklog,
                deltaBacklog,
                reason);
    }

    private CameraOpsHealthResponse opsHealth(String status) {
        return opsHealth(status, List.of());
    }

    private CameraOpsHealthResponse opsHealth(String status, List<String> issues) {
        return new CameraOpsHealthResponse(
                status,
                "healthy".equals(status) ? 100 : 70,
                1,
                "healthy".equals(status) ? 1 : 0,
                "degraded".equals(status) ? 1 : 0,
                "critical".equals(status) ? 1 : 0,
                0,
                0,
                0,
                0,
                issues,
                List.of(),
                List.of(),
                List.of(),
                NOW);
    }

    private CameraContextResponse context(
            int hiddenVisibilityCandidateCount,
            int visibilityAudienceAttentionLayerCount) {
        return context(hiddenVisibilityCandidateCount, visibilityAudienceAttentionLayerCount, false);
    }

    private CameraContextResponse context(
            int hiddenVisibilityCandidateCount,
            int visibilityAudienceAttentionLayerCount,
            boolean minimapClipped) {
        return new CameraContextResponse(
                "viewer",
                null,
                0,
                0,
                summary(hiddenVisibilityCandidateCount, visibilityAudienceAttentionLayerCount),
                null,
                null,
                minimap(minimapClipped),
                List.of(),
                List.of(),
                NOW);
    }

    private CameraMinimap minimap(boolean clipped) {
        return new CameraMinimap(
                "heading_up",
                null,
                100.0,
                0.0,
                0.0,
                0.0,
                -1.0,
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                clipped,
                clipped ? 1 : 0,
                clipped ? 2 : 1,
                clipped ? 2 : 1,
                0,
                false);
    }

    private CameraContextSummary summary(
            int hiddenVisibilityCandidateCount,
            int visibilityAudienceAttentionLayerCount) {
        return new CameraContextSummary(
                1,
                1,
                0,
                0,
                hiddenVisibilityCandidateCount > 0 || visibilityAudienceAttentionLayerCount > 0 ? 1 : 0,
                hiddenVisibilityCandidateCount,
                visibilityAudienceAttentionLayerCount,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                null,
                null,
                null);
    }

    private CameraSessionSyncLinks links(String nextSyncHref, String streamHref) {
        return new CameraSessionSyncLinks(
                nextSyncHref,
                "/camera/sessions/session/context",
                "/camera/sessions/session/minimap",
                "/camera/sessions/session/minimap/expansion",
                "/camera/sessions/session/memories/nearby",
                "/camera/ops/health?viewerId=viewer",
                "/camera/sessions/session/events?afterSequence=10",
                streamHref,
                CameraSyncContract.CAPABILITIES_HREF);
    }
}
