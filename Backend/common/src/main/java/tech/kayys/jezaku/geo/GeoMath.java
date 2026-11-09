package tech.kayys.jezaku.geo;

import jakarta.ws.rs.BadRequestException;

public final class GeoMath {
    private static final double EARTH_RADIUS_METERS = 6_371_000.0;

    private GeoMath() {
    }

    public static void validateLatLng(double latitude, double longitude) {
        if (!Double.isFinite(latitude) || latitude < -90.0 || latitude > 90.0) {
            throw new BadRequestException("latitude must be between -90 and 90");
        }
        if (!Double.isFinite(longitude) || longitude < -180.0 || longitude > 180.0) {
            throw new BadRequestException("longitude must be between -180 and 180");
        }
    }

    public static double distanceMeters(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude) {
        double lat1 = Math.toRadians(fromLatitude);
        double lat2 = Math.toRadians(toLatitude);
        double deltaLat = Math.toRadians(toLatitude - fromLatitude);
        double deltaLng = Math.toRadians(toLongitude - fromLongitude);
        double a = Math.sin(deltaLat / 2.0) * Math.sin(deltaLat / 2.0)
                + Math.cos(lat1) * Math.cos(lat2)
                * Math.sin(deltaLng / 2.0) * Math.sin(deltaLng / 2.0);
        double c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
        return EARTH_RADIUS_METERS * c;
    }

    public static double bearingDegrees(double fromLatitude, double fromLongitude, double toLatitude, double toLongitude) {
        double lat1 = Math.toRadians(fromLatitude);
        double lat2 = Math.toRadians(toLatitude);
        double deltaLng = Math.toRadians(toLongitude - fromLongitude);
        double y = Math.sin(deltaLng) * Math.cos(lat2);
        double x = Math.cos(lat1) * Math.sin(lat2)
                - Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLng);
        return (Math.toDegrees(Math.atan2(y, x)) + 360.0) % 360.0;
    }

    public static Double normalizeDegrees(Double degrees) {
        return normalizeDegrees(degrees, "degrees");
    }

    public static Double normalizeDegrees(Double degrees, String field) {
        if (degrees == null) {
            return null;
        }
        if (!Double.isFinite(degrees)) {
            throw new BadRequestException(field + " must be finite");
        }
        double normalized = degrees % 360.0;
        if (normalized < 0.0) {
            normalized += 360.0;
        }
        return round2(normalized);
    }

    public static RelativeOffset relativeOffset(double distanceMeters, double bearingDegrees, double radiusMeters) {
        double normalizedDistance = distanceRatio(distanceMeters, radiusMeters);
        double radians = Math.toRadians(bearingDegrees);
        return new RelativeOffset(
                round2(Math.sin(radians) * normalizedDistance),
                round2(-Math.cos(radians) * normalizedDistance));
    }

    public static RelativeOffset relativeOffsetFromOrientation(
            double distanceMeters,
            double bearingDegrees,
            double orientationDegrees,
            double radiusMeters) {
        return relativeOffset(distanceMeters, relativeBearingDegrees(bearingDegrees, orientationDegrees), radiusMeters);
    }

    public static double distanceRatio(double distanceMeters, double radiusMeters) {
        return round2(Math.min(distanceMeters, radiusMeters) / radiusMeters);
    }

    public static double relativeBearingDegrees(double bearingDegrees, double orientationDegrees) {
        double relative = (bearingDegrees - orientationDegrees) % 360.0;
        if (relative < 0.0) {
            relative += 360.0;
        }
        double rounded = round2(relative);
        return rounded >= 360.0 ? 0.0 : rounded;
    }

    public static double orientationDegrees(Double headingDegrees, Double compassDegrees) {
        if (compassDegrees != null) {
            return compassDegrees;
        }
        if (headingDegrees != null) {
            return headingDegrees;
        }
        return 0.0;
    }

    public static Double altitudeDeltaMeters(Double originAltitudeMeters, Double targetAltitudeMeters) {
        if (originAltitudeMeters == null || targetAltitudeMeters == null) {
            return null;
        }
        return round2(targetAltitudeMeters - originAltitudeMeters);
    }

    public static double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    public static double round1(double value) {
        return Math.round(value * 10.0) / 10.0;
    }

    public record RelativeOffset(double x, double y) {
    }
}
