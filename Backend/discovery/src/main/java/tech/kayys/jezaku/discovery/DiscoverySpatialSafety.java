package tech.kayys.jezaku.discovery;

import tech.kayys.jezaku.discovery.DiscoveryDtos.GeoPoint;

import java.util.List;

/** Server-side spatial discovery policy boundary. */
interface DiscoverySpatialSafety {
    /** Returns one policy outcome per point, preserving input order. */
    List<String> evaluate(List<GeoPoint> positions);

    static DiscoverySpatialSafety allowAll() {
        return positions -> positions.stream().map(ignored -> "ALLOWED").toList();
    }
}
