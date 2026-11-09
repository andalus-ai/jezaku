package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityReference;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncClientHints;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;

import java.util.ArrayList;
import java.util.List;

final class CameraSessionSyncClientHintPolicies {
    private CameraSessionSyncClientHintPolicies() {
    }

    static CameraSessionSyncClientHints from(
            CameraSessionSyncCapabilityReference capabilitiesRef,
            CameraSessionSyncPlan syncPlan,
            CameraOpsHealthResponse opsHealth,
            CameraSessionSyncLinks links) {
        return from(capabilitiesRef, syncPlan, opsHealth, null, links);
    }

    static CameraSessionSyncClientHints from(
            CameraSessionSyncCapabilityReference capabilitiesRef,
            CameraSessionSyncPlan syncPlan,
            CameraOpsHealthResponse opsHealth,
            CameraContextResponse context,
            CameraSessionSyncLinks links) {
        boolean preferSync = preferSync(syncPlan, opsHealth, context);
        boolean streamAvailable = links != null && text(links.streamHref());
        String preferredTransport = preferSync || !streamAvailable
                ? CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC
                : CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE;
        boolean useCachedCapabilities = capabilitiesRef != null
                && !capabilitiesRef.included()
                && capabilitiesRef.clientCacheFresh();
        boolean offlineSafe = capabilitiesRef != null
                && (capabilitiesRef.included() || capabilitiesRef.clientCacheFresh());

        return new CameraSessionSyncClientHints(
                capabilitiesRef != null && capabilitiesRef.refreshRecommended(),
                capabilitiesRef == null ? null : capabilitiesRef.etag(),
                capabilitiesRef == null ? null : capabilitiesRef.href(),
                useCachedCapabilities,
                preferredTransport,
                preferredHref(preferredTransport, links),
                links == null ? null : links.streamHref(),
                links == null ? null : links.nextSyncHref(),
                streamAvailable && CameraSyncContract.CLIENT_HINT_TRANSPORT_SSE.equals(preferredTransport),
                CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC.equals(preferredTransport),
                offlineSafe,
                reasons(capabilitiesRef, syncPlan, opsHealth, context, streamAvailable));
    }

    private static boolean preferSync(
            CameraSessionSyncPlan syncPlan,
            CameraOpsHealthResponse opsHealth,
            CameraContextResponse context) {
        if (syncPlan == null) {
            return true;
        }
        if (syncPlan.eventBacklog() || syncPlan.deltaBacklog()) {
            return true;
        }
        if (CameraSyncContract.SYNC_REASON_OPS_HEALTH_CRITICAL.equals(syncPlan.reason())
                || CameraSyncContract.SYNC_REASON_OPS_HEALTH_DEGRADED.equals(syncPlan.reason())) {
            return true;
        }
        return (opsHealth != null && !"healthy".equals(opsHealth.status()))
                || hasVisibilityAudienceAttention(context);
    }

    private static String preferredHref(String preferredTransport, CameraSessionSyncLinks links) {
        if (links == null) {
            return null;
        }
        return CameraSyncContract.CLIENT_HINT_TRANSPORT_SYNC.equals(preferredTransport)
                ? links.nextSyncHref()
                : links.streamHref();
    }

    private static List<String> reasons(
            CameraSessionSyncCapabilityReference capabilitiesRef,
            CameraSessionSyncPlan syncPlan,
            CameraOpsHealthResponse opsHealth,
            CameraContextResponse context,
            boolean streamAvailable) {
        List<String> reasons = new ArrayList<>();
        if (capabilitiesRef != null && capabilitiesRef.refreshRecommended()) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_REFRESH_RECOMMENDED);
        } else if (capabilitiesRef != null && capabilitiesRef.clientCacheFresh()) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_CACHE_FRESH);
        } else if (capabilitiesRef != null && capabilitiesRef.included()) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_CAPABILITIES_INCLUDED);
        }
        if (streamAvailable) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_EVENT_STREAM_AVAILABLE);
        }
        if (syncPlan != null && (syncPlan.eventBacklog() || syncPlan.deltaBacklog())) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_SYNC_BACKLOG);
        }
        if (opsHealth != null && !"healthy".equals(opsHealth.status())) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_OPS_HEALTH_ATTENTION);
        }
        if (hasVisibilityAudienceAttention(opsHealth) || hasVisibilityAudienceAttention(context)) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_AUDIENCE_ATTENTION);
        }
        if (hasVisibilityPressure(context)) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_VISIBILITY_PRESSURE);
        }
        if (hasClippedMinimap(context)) {
            reasons.add(CameraSyncContract.CLIENT_HINT_REASON_MINIMAP_CLIPPED);
        }
        return List.copyOf(reasons);
    }

    private static boolean hasVisibilityAudienceAttention(CameraOpsHealthResponse opsHealth) {
        return opsHealth != null
                && opsHealth.issues() != null
                && opsHealth.issues().stream()
                        .anyMatch(issue -> issue != null && issue.startsWith("visibility_audience_"));
    }

    private static boolean hasVisibilityAudienceAttention(CameraContextResponse context) {
        CameraContextSummary summary = context == null ? null : context.summary();
        return summary != null && summary.visibilityAudienceAttentionLayerCount() > 0;
    }

    private static boolean hasVisibilityPressure(CameraContextResponse context) {
        CameraContextSummary summary = context == null ? null : context.summary();
        return summary != null && summary.hiddenVisibilityCandidateCount() > 0;
    }

    private static boolean hasClippedMinimap(CameraContextResponse context) {
        return context != null
                && context.minimap() != null
                && context.minimap().hasClippedPins();
    }

    private static boolean text(String value) {
        return value != null && !value.isBlank();
    }
}
