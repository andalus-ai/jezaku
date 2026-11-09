package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionStreamDescriptor;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncLinks;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Builds canonical follow-up links for camera session sync responses.
 */
final class CameraSessionSyncLinksBuilder {
    private CameraSessionSyncLinksBuilder() {
    }

    static CameraSessionStreamDescriptor streamDescriptor(
            String sessionId,
            CameraSessionEventListResponse events,
            int maxEvents) {
        String href = "/camera/sessions/" + sessionId
                + "/stream?afterSequence=" + events.lastSequence()
                + "&maxEvents=" + maxEvents;
        return new CameraSessionStreamDescriptor(
                href,
                "text/event-stream",
                events.lastSequence(),
                maxEvents,
                CameraSyncContract.STREAM_RETRY_MILLIS);
    }

    static CameraSessionSyncLinks links(Request request) {
        String base = "/camera/sessions/" + request.sessionId();
        String contextQuery = query(List.of(
                queryParam("radiusMeters", request.radiusMeters()),
                queryParam("limitPerLayer", request.limitPerLayer()),
                queryParam("layers", request.layers())));
        String minimapQuery = query(List.of(
                queryParam("radiusMeters", request.radiusMeters()),
                queryParam("limitPerLayer", request.limitPerLayer()),
                queryParam("minimapPinLimitPerLayer", nonDefaultMinimapPinLimit(
                        request.minimapPinLimitPerLayer())),
                queryParam("layers", request.layers())));
        String nearbyMemoriesQuery = query(List.of(
                queryParam("radiusMeters", request.radiusMeters()),
                queryParam("limitPerLayer", request.limitPerLayer())));
        String nextSyncQuery = query(List.of(
                queryParam("radiusMeters", request.radiusMeters()),
                queryParam("limitPerLayer", request.limitPerLayer()),
                queryParam("minimapPinLimitPerLayer", nonDefaultMinimapPinLimit(
                        request.minimapPinLimitPerLayer())),
                queryParam("layers", request.layers()),
                queryParam("eventLimit", request.eventLimit()),
                queryParam("afterSequence", request.events().lastSequence()),
                queryParam("contextDeltaLimit", request.contextDeltaLimit()),
                queryParam("capabilitiesMode", nonDefaultCapabilitiesMode(request.capabilitiesMode())),
                queryParam("capabilitiesEtag", thinCapabilitiesEtag(
                        request.capabilitiesMode(),
                        request.capabilitiesEtag())),
                queryParam("sections", request.sectionSelection().queryValue())));
        String eventsQuery = query(List.of(
                queryParam("afterSequence", request.events().lastSequence()),
                queryParam("limit", request.eventLimit())));
        return new CameraSessionSyncLinks(
                base + "/sync" + nextSyncQuery,
                base + "/context" + contextQuery,
                base + "/minimap" + minimapQuery,
                base + "/minimap/expansion" + minimapQuery,
                base + "/memories/nearby" + nearbyMemoriesQuery,
                opsHealthHref(request.context(), request.limitPerLayer(), request.layers()),
                base + "/events" + eventsQuery,
                request.stream().href(),
                CameraSyncContract.CAPABILITIES_HREF);
    }

    private static Integer nonDefaultMinimapPinLimit(int value) {
        return value == CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER ? null : value;
    }

    private static String nonDefaultCapabilitiesMode(String value) {
        return CameraSyncContract.DEFAULT_CAPABILITIES_MODE.equals(value) ? null : value;
    }

    private static String thinCapabilitiesEtag(String capabilitiesMode, String capabilitiesEtag) {
        return CameraSyncContract.CAPABILITIES_MODE_ETAG.equals(capabilitiesMode) ? capabilitiesEtag : null;
    }

    private static String opsHealthHref(
            CameraContextResponse context,
            Integer limitPerLayer,
            String layers) {
        if (context == null || context.telemetry() == null || context.telemetry().position() == null) {
            return "/camera/ops/health" + query(List.of(
                    queryParam("limitPerLayer", limitPerLayer),
                    queryParam("layers", layers)));
        }
        return "/camera/ops/health" + query(List.of(
                queryParam("viewerId", context.viewerId()),
                queryParam("lat", context.telemetry().position().latitude()),
                queryParam("lng", context.telemetry().position().longitude()),
                queryParam("altitudeMeters", context.telemetry().position().altitudeMeters()),
                queryParam("headingDegrees", context.telemetry().headingDegrees()),
                queryParam("compassDegrees", context.telemetry().compassDegrees()),
                queryParam("speedMetersPerSecond", context.telemetry().speedMetersPerSecond()),
                queryParam("radiusMeters", context.telemetry().radiusMeters()),
                queryParam("limitPerLayer", limitPerLayer),
                queryParam("layers", layers)));
    }

    private static QueryParamValue queryParam(String name, Object value) {
        return new QueryParamValue(name, value == null ? null : value.toString());
    }

    private static String query(List<QueryParamValue> params) {
        List<String> parts = new ArrayList<>();
        for (QueryParamValue param : params) {
            if (param.value() == null || param.value().isBlank()) {
                continue;
            }
            parts.add(encode(param.name()) + "=" + encode(param.value()));
        }
        return parts.isEmpty() ? "" : "?" + String.join("&", parts);
    }

    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    record Request(
            String sessionId,
            Double radiusMeters,
            Integer limitPerLayer,
            int minimapPinLimitPerLayer,
            String layers,
            int eventLimit,
            int contextDeltaLimit,
            String capabilitiesMode,
            String capabilitiesEtag,
            CameraSessionSyncSectionSelection sectionSelection,
            CameraContextResponse context,
            CameraSessionEventListResponse events,
            CameraSessionStreamDescriptor stream) {
    }

    private record QueryParamValue(String name, String value) {
    }
}
