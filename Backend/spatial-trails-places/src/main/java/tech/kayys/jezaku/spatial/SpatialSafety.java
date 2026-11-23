package tech.kayys.jezaku.spatial;

import tech.kayys.jezaku.spatial.SpatialDtos.GeoPoint;

import java.util.List;

/** Spatial policy boundary owned by the Safety service. */
public interface SpatialSafety {
    void requirePublishPermitted(GeoPoint position);

    List<String> evaluate(String activity, List<GeoPoint> positions);

    static SpatialSafety allowAll() {
        return new SpatialSafety() {
            @Override
            public void requirePublishPermitted(GeoPoint position) {
            }

            @Override
            public List<String> evaluate(String activity, List<GeoPoint> positions) {
                return positions.stream().map(ignored -> "ALLOWED").toList();
            }
        };
    }
}
