package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFeed;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFeedLinks;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Builds canonical follow-up links for standalone and session nearby-memory feeds.
 */
final class CameraNearbyMemoryFeedLinksBuilder {
    private CameraNearbyMemoryFeedLinksBuilder() {
    }

    static CameraNearbyMemoryFeedLinks standalone(
            CameraNearbyMemoryFeed feed,
            StandaloneRequest request) {
        if (!hasNextPage(feed)) {
            return new CameraNearbyMemoryFeedLinks(null);
        }
        return new CameraNearbyMemoryFeedLinks("/camera/memories/nearby" + query(List.of(
                queryParam("viewerId", request.viewerId()),
                queryParam("lat", request.lat()),
                queryParam("lng", request.lng()),
                queryParam("altitudeMeters", request.altitudeMeters()),
                queryParam("headingDegrees", request.headingDegrees()),
                queryParam("compassDegrees", request.compassDegrees()),
                queryParam("speedMetersPerSecond", request.speedMetersPerSecond()),
                queryParam("gpsAccuracyMeters", request.gpsAccuracyMeters()),
                queryParam("altitudeAccuracyMeters", request.altitudeAccuracyMeters()),
                queryParam("headingAccuracyDegrees", request.headingAccuracyDegrees()),
                queryParam("compassAccuracyDegrees", request.compassAccuracyDegrees()),
                queryParam("motionState", request.motionState()),
                queryParam("radiusMeters", request.radiusMeters()),
                queryParam("limitPerLayer", request.limitPerLayer()),
                queryParam("feedMode", feed.filter().mode()),
                queryParam("ownerId", feed.filter().ownerId()),
                queryParam("includeNeedsRefinement", feed.filter().includeNeedsRefinement()),
                queryParam("pageSize", feed.pageSize()),
                queryParam("pageCursor", feed.nextCursor()),
                queryParam("sortBy", feed.sort().field()),
                queryParam("sortDirection", feed.sort().direction()))));
    }

    static CameraNearbyMemoryFeedLinks session(
            CameraNearbyMemoryFeed feed,
            SessionRequest request) {
        if (!hasNextPage(feed)) {
            return new CameraNearbyMemoryFeedLinks(null);
        }
        return new CameraNearbyMemoryFeedLinks("/camera/sessions/" + request.sessionId()
                + "/memories/nearby" + query(List.of(
                        queryParam("radiusMeters", request.radiusMeters()),
                        queryParam("limitPerLayer", request.limitPerLayer()),
                        queryParam("feedMode", feed.filter().mode()),
                        queryParam("ownerId", feed.filter().ownerId()),
                        queryParam("includeNeedsRefinement", feed.filter().includeNeedsRefinement()),
                        queryParam("pageSize", feed.pageSize()),
                        queryParam("pageCursor", feed.nextCursor()),
                        queryParam("sortBy", feed.sort().field()),
                        queryParam("sortDirection", feed.sort().direction()))));
    }

    private static boolean hasNextPage(CameraNearbyMemoryFeed feed) {
        return feed != null && feed.hasMore() && feed.nextCursor() != null && !feed.nextCursor().isBlank();
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

    record StandaloneRequest(
            String viewerId,
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            String motionState,
            Double radiusMeters,
            Integer limitPerLayer) {
    }

    record SessionRequest(
            String sessionId,
            Double radiusMeters,
            Integer limitPerLayer) {
    }

    private record QueryParamValue(String name, String value) {
    }
}
