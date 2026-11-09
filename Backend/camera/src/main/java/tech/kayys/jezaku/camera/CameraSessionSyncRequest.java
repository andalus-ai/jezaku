package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedLong;

/**
 * Normalized query contract for one camera session sync request.
 */
record CameraSessionSyncRequest(
        String sessionId,
        Double radiusMeters,
        Integer limitPerLayer,
        int minimapPinLimitPerLayer,
        String layers,
        int eventLimit,
        long afterSequence,
        int contextDeltaLimit,
        String capabilitiesMode,
        String capabilitiesEtag,
        String sections) {
    CameraSessionSyncRequest {
        eventLimit = normalizeBoundedInt(
                eventLimit,
                CameraSyncContract.DEFAULT_EVENT_LIMIT,
                CameraSyncContract.MIN_EVENT_LIMIT,
                CameraSyncContract.MAX_EVENT_LIMIT,
                "eventLimit");
        afterSequence = normalizeBoundedLong(
                afterSequence,
                CameraSyncContract.MIN_CURSOR,
                Long.MAX_VALUE,
                "afterSequence");
        contextDeltaLimit = normalizeBoundedInt(
                contextDeltaLimit,
                CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT,
                CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT,
                CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT,
                "contextDeltaLimit");
        minimapPinLimitPerLayer = normalizeBoundedInt(
                minimapPinLimitPerLayer,
                CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER,
                CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER,
                "minimapPinLimitPerLayer");
    }

    static CameraSessionSyncRequest fromRaw(
            String sessionId,
            Double radiusMeters,
            Integer limitPerLayer,
            Integer minimapPinLimitPerLayer,
            String layers,
            Integer eventLimit,
            Long afterSequence,
            Integer contextDeltaLimit,
            String capabilitiesMode,
            String capabilitiesEtag,
            String sections) {
        return new CameraSessionSyncRequest(
                sessionId,
                radiusMeters,
                limitPerLayer,
                normalizeBoundedInt(
                        minimapPinLimitPerLayer,
                        CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                        CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER,
                        CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER,
                        "minimapPinLimitPerLayer"),
                layers,
                normalizeBoundedInt(
                        eventLimit,
                        CameraSyncContract.DEFAULT_EVENT_LIMIT,
                        CameraSyncContract.MIN_EVENT_LIMIT,
                        CameraSyncContract.MAX_EVENT_LIMIT,
                        "eventLimit"),
                normalizeBoundedLong(
                        afterSequence,
                        CameraSyncContract.DEFAULT_CURSOR,
                        CameraSyncContract.MIN_CURSOR,
                        Long.MAX_VALUE,
                        "afterSequence"),
                normalizeBoundedInt(
                        contextDeltaLimit,
                        CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT,
                        CameraSyncContract.MIN_CONTEXT_DELTA_LIMIT,
                        CameraSyncContract.MAX_CONTEXT_DELTA_LIMIT,
                        "contextDeltaLimit"),
                capabilitiesMode,
                capabilitiesEtag,
                sections);
    }

    CameraSessionSyncLinksBuilder.Request linksRequest(
            String normalizedCapabilitiesMode,
            CameraSessionSyncSectionSelection sectionSelection,
            CameraContextResponse context,
            CameraSessionEventListResponse events,
            CameraSessionStreamDescriptor stream) {
        return new CameraSessionSyncLinksBuilder.Request(
                sessionId,
                radiusMeters,
                limitPerLayer,
                minimapPinLimitPerLayer(),
                layers,
                eventLimit(),
                contextDeltaLimit(),
                normalizedCapabilitiesMode,
                capabilitiesEtag,
                sectionSelection,
                context,
                events,
                stream);
    }
}
