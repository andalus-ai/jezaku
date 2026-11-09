package tech.kayys.jezaku.camera;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncClientHints;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncFreshness;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncResponse;

import java.time.Instant;

@ApplicationScoped
class CameraSessionSyncAssembler {
    @Inject
    CameraContextDeltaService contextDeltas;

    CameraSessionSyncResponse assemble(
            CameraSessionSyncRequest request,
            CameraSessionSyncCapabilityNegotiation capabilities,
            CameraSessionSyncSectionSelection sectionSelection,
            CameraSessionResponse sessionResponse,
            CameraContextResponse context,
            CameraSessionEventListResponse events) {
        Instant generatedAt = Instant.now();
        boolean needsPresentationContext = sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CONTEXT)
                || sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CLIENT_HINTS);
        CameraContextResponse responseContext = needsPresentationContext
                ? CameraContextMinimapOverrides.withPinLimit(context, request.minimapPinLimitPerLayer())
                : context;
        CameraSessionStreamDescriptor stream = CameraSessionSyncLinksBuilder.streamDescriptor(
                request.sessionId(),
                events,
                request.eventLimit());
        CameraSessionSyncWorkPlan workPlan = CameraSessionSyncWorkPlan.from(sectionSelection);
        CameraContextDeltaResponse contextDelta = workPlan.needsContextDelta()
                ? contextDeltas.delta(
                        request.sessionId(),
                        context,
                        generatedAt,
                        request.contextDeltaLimit())
                : null;
        CameraOpsHealthResponse opsHealth = workPlan.needsOpsHealth()
                ? CameraOpsHealthReports.from(context, generatedAt)
                : null;
        CameraSessionSyncLinks links = CameraSessionSyncLinksBuilder.links(request.linksRequest(
                capabilities.mode(),
                sectionSelection,
                context,
                events,
                stream));
        CameraSessionSyncPlan syncPlan = workPlan.needsSyncPlan()
                ? CameraSessionSyncPlans.from(
                        sessionResponse,
                        context,
                        events,
                        contextDelta,
                        opsHealth,
                        generatedAt)
                : null;
        CameraSessionSyncClientHints clientHints = sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CLIENT_HINTS)
                ? CameraSessionSyncClientHintPolicies.from(
                        capabilities.reference(),
                        syncPlan,
                        opsHealth,
                        responseContext,
                        links)
                : null;
        CameraSessionSyncFreshness freshness = sectionSelection.includes(CameraSyncContract.SYNC_SECTION_FRESHNESS)
                ? CameraSessionSyncFreshnessPolicies.from(
                        syncPlan,
                        generatedAt)
                : null;
        return CameraSessionSyncResponseProjector.project(
                sectionSelection,
                new CameraSessionSyncResponseProjector.Payload(
                        sessionResponse,
                        responseContext,
                        events,
                        stream,
                        links,
                        contextDelta,
                        opsHealth,
                        syncPlan,
                        clientHints,
                        freshness,
                        capabilities.reference(),
                        capabilities.capabilities(),
                        generatedAt));
    }
}
