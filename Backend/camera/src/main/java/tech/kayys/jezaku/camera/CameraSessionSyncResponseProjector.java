package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilities;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityReference;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncClientHints;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncFreshness;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncResponse;

import java.time.Instant;

final class CameraSessionSyncResponseProjector {
    private CameraSessionSyncResponseProjector() {
    }

    static CameraSessionSyncResponse project(
            CameraSessionSyncSectionSelection sectionSelection,
            Payload payload) {
        return new CameraSessionSyncResponse(
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_SESSION) ? payload.session() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CONTEXT) ? payload.context() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_EVENTS) ? payload.events() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_STREAM) ? payload.stream() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_LINKS) ? payload.links() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CONTEXT_DELTA)
                        ? payload.contextDelta()
                        : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_OPS_HEALTH) ? payload.opsHealth() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_SYNC_PLAN) ? payload.syncPlan() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CLIENT_HINTS)
                        ? payload.clientHints()
                        : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_FRESHNESS) ? payload.freshness() : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CAPABILITIES_REF)
                        ? payload.capabilitiesRef()
                        : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CAPABILITIES)
                        ? payload.capabilities()
                        : null,
                sectionSelection.includes(CameraSyncContract.SYNC_SECTION_GENERATED_AT)
                        ? payload.generatedAt()
                        : null);
    }

    record Payload(
            CameraSessionResponse session,
            CameraContextResponse context,
            CameraSessionEventListResponse events,
            CameraSessionStreamDescriptor stream,
            CameraSessionSyncLinks links,
            CameraContextDeltaResponse contextDelta,
            CameraOpsHealthResponse opsHealth,
            CameraSessionSyncPlan syncPlan,
            CameraSessionSyncClientHints clientHints,
            CameraSessionSyncFreshness freshness,
            CameraSessionSyncCapabilityReference capabilitiesRef,
            CameraSessionSyncCapabilities capabilities,
            Instant generatedAt) {
    }
}
