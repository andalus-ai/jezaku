package tech.kayys.jezaku.safety;

import tech.kayys.jezaku.geo.GeoMath;

import java.util.ArrayList;
import java.util.List;

/**
 * Validates bounded WGS84 route polylines and measures spherical
 * great-circle segment distance. This is a policy-intersection primitive,
 * not a routing engine or a guarantee of physical passability.
 */
public final class SpatialRouteGeometry {
    public static final int MAX_VERTICES = 2_000;
    public static final double MAX_SEGMENT_LENGTH_METERS = 100_000.0;
    public static final double MAX_ROUTE_LENGTH_METERS = 500_000.0;
    public static final double MAX_CORRIDOR_BUFFER_METERS = 500.0;

    private static final double EARTH_RADIUS_METERS = 6_371_000.0;
    private static final double MIN_SEGMENT_LENGTH_METERS = 0.01;

    private SpatialRouteGeometry() {
    }

    public static ValidatedRoute validate(List<Point> points, double corridorBufferMeters) {
        if (points == null || points.size() < 2 || points.size() > MAX_VERTICES) {
            throw new IllegalArgumentException("route must contain 2 to " + MAX_VERTICES + " vertices");
        }
        if (!Double.isFinite(corridorBufferMeters)
                || corridorBufferMeters < 0
                || corridorBufferMeters > MAX_CORRIDOR_BUFFER_METERS) {
            throw new IllegalArgumentException("corridorBufferMeters is outside the supported range");
        }

        List<Point> stablePoints = List.copyOf(points);
        double totalLengthMeters = 0;
        for (int index = 0; index < stablePoints.size(); index++) {
            Point point = stablePoints.get(index);
            if (point == null) {
                throw new IllegalArgumentException("route vertices must not be null");
            }
            validateCoordinate(point.latitude(), point.longitude());
            if (index == 0) {
                continue;
            }
            Point previous = stablePoints.get(index - 1);
            double segmentLength = GeoMath.distanceMeters(
                    previous.latitude(), previous.longitude(), point.latitude(), point.longitude());
            if (segmentLength < MIN_SEGMENT_LENGTH_METERS) {
                throw new IllegalArgumentException("route contains a duplicate or degenerate segment");
            }
            if (segmentLength > MAX_SEGMENT_LENGTH_METERS) {
                throw new IllegalArgumentException("route segment exceeds the maximum length");
            }
            totalLengthMeters += segmentLength;
            if (totalLengthMeters > MAX_ROUTE_LENGTH_METERS) {
                throw new IllegalArgumentException("route exceeds the maximum total length");
            }
        }
        return new ValidatedRoute(stablePoints, corridorBufferMeters, totalLengthMeters);
    }

    /**
     * Returns the minimum spherical distance from a point to the finite
     * great-circle arc between two route vertices. Cross-track distance is
     * used only when the perpendicular projection falls within the segment;
     * otherwise the nearer endpoint is used.
     */
    public static double minimumDistanceToSegmentMeters(Point point, Point start, Point end) {
        validateCoordinate(point.latitude(), point.longitude());
        validateCoordinate(start.latitude(), start.longitude());
        validateCoordinate(end.latitude(), end.longitude());

        double segmentLength = GeoMath.distanceMeters(
                start.latitude(), start.longitude(), end.latitude(), end.longitude());
        if (segmentLength < MIN_SEGMENT_LENGTH_METERS) {
            return GeoMath.distanceMeters(
                    point.latitude(), point.longitude(), start.latitude(), start.longitude());
        }

        double distanceFromStart = GeoMath.distanceMeters(
                start.latitude(), start.longitude(), point.latitude(), point.longitude());
        double angularDistance = distanceFromStart / EARTH_RADIUS_METERS;
        if (angularDistance < 1.0e-12) {
            return 0;
        }

        double routeBearing = Math.toRadians(GeoMath.bearingDegrees(
                start.latitude(), start.longitude(), end.latitude(), end.longitude()));
        double pointBearing = Math.toRadians(GeoMath.bearingDegrees(
                start.latitude(), start.longitude(), point.latitude(), point.longitude()));
        double bearingDelta = pointBearing - routeBearing;

        double crossTrackArgument = Math.sin(angularDistance) * Math.sin(bearingDelta);
        double crossTrackMeters = Math.asin(clamp(crossTrackArgument)) * EARTH_RADIUS_METERS;
        double alongTrackMeters = Math.atan2(
                Math.sin(angularDistance) * Math.cos(bearingDelta),
                Math.cos(angularDistance)) * EARTH_RADIUS_METERS;

        if (alongTrackMeters < 0) {
            return distanceFromStart;
        }
        if (alongTrackMeters > segmentLength) {
            return GeoMath.distanceMeters(
                    point.latitude(), point.longitude(), end.latitude(), end.longitude());
        }
        return Math.abs(crossTrackMeters);
    }

    private static void validateCoordinate(double latitude, double longitude) {
        if (!Double.isFinite(latitude) || latitude < -90 || latitude > 90
                || !Double.isFinite(longitude) || longitude < -180 || longitude > 180) {
            throw new IllegalArgumentException("route coordinates must be finite WGS84 latitude/longitude");
        }
    }

    private static double clamp(double value) {
        return Math.max(-1.0, Math.min(1.0, value));
    }

    public record Point(double latitude, double longitude) {
    }

    public record ValidatedRoute(List<Point> points, double corridorBufferMeters, double totalLengthMeters) {
        public ValidatedRoute {
            points = List.copyOf(points);
        }
    }
}
