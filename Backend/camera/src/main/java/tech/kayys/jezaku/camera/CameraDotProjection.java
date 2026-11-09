package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;
import tech.kayys.jezaku.geo.GeoMath.RelativeOffset;

import static tech.kayys.jezaku.geo.GeoMath.altitudeDeltaMeters;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.distanceRatio;
import static tech.kayys.jezaku.geo.GeoMath.relativeBearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffsetFromOrientation;
import static tech.kayys.jezaku.geo.GeoMath.round2;

final class CameraDotProjection {
    private CameraDotProjection() {
    }

    static Projection from(GeoPoint origin, GeoPoint target, double orientationDegrees, double radiusMeters) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(), target.latitude(), target.longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(), target.latitude(), target.longitude());
        RelativeOffset offset = relativeOffsetFromOrientation(distance, bearing, orientationDegrees, radiusMeters);
        return new Projection(
                round2(distance),
                distanceRatio(distance, radiusMeters),
                round2(bearing),
                relativeBearingDegrees(bearing, orientationDegrees),
                offset.x(),
                offset.y(),
                altitudeDeltaMeters(origin.altitudeMeters(), target.altitudeMeters()));
    }

    record Projection(
            double distanceMeters,
            double distanceRatio,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters) {
    }
}
