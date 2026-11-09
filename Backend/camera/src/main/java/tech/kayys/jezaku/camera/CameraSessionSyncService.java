package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncResponse;

import java.time.Instant;

@ApplicationScoped
public class CameraSessionSyncService {
    @Inject
    CameraLiveSessionService liveSessions;

    @Inject
    CameraSessionContextQueries sessionContexts;

    @Inject
    CameraSessionSyncAssembler assembler;

    public Uni<CameraSessionSyncResponse> sync(CameraSessionSyncRequest request) {
        Instant now = Instant.now();
        CameraSessionSyncSectionSelection sectionSelection = CameraSessionSyncSectionSelection.from(request.sections());
        CameraSessionSyncCapabilityNegotiation capabilities = CameraSessionSyncCapabilityNegotiation.from(
                request.capabilitiesMode(),
                request.capabilitiesEtag(),
                sectionSelection);
        CameraSessionRecord session = liveSessions.activeSession(request.sessionId(), now);
        CameraSessionResponse sessionResponse = liveSessions.response(session, now);
        return sessionContexts.forSession(
                session,
                request.radiusMeters(),
                request.limitPerLayer(),
                request.layers())
                .chain(context -> liveSessions.events(
                        request.sessionId(),
                        request.eventLimit(),
                        request.afterSequence())
                        .map(events -> assembler.assemble(
                                request,
                                capabilities,
                                sectionSelection,
                                sessionResponse,
                                context,
                                events)));
    }
}
