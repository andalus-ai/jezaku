package tech.kayys.jezaku.presence;

import tech.kayys.jezaku.presence.PresenceDtos.GeoPoint;
import tech.kayys.jezaku.presence.PresenceDtos.MinimapDot;
import tech.kayys.jezaku.presence.PresenceDtos.NearbyPresence;

import java.time.Instant;

import static tech.kayys.jezaku.geo.GeoMath.altitudeDeltaMeters;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.distanceRatio;
import static tech.kayys.jezaku.geo.GeoMath.relativeBearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffsetFromOrientation;
import static tech.kayys.jezaku.geo.GeoMath.round2;

final class PresenceSpatialProjection {
    private PresenceSpatialProjection() {
    }

    static Projection from(
            PresenceRecord record,
            GeoPoint origin,
            double orientationDegrees,
            double radiusMeters,
            Instant now) {
        double distance = distanceMeters(
                origin.latitude(),
                origin.longitude(),
                record.position().latitude(),
                record.position().longitude());
        double bearing = bearingDegrees(
                origin.latitude(),
                origin.longitude(),
                record.position().latitude(),
                record.position().longitude());
        double ratio = distanceRatio(distance, radiusMeters);
        long ageSeconds = PresenceDotPresentation.secondsSince(record.observedAt(), now);
        long expiresInSeconds = PresenceDotPresentation.secondsUntil(record.expiresAt(), now);
        var offset = relativeOffsetFromOrientation(distance, bearing, orientationDegrees, radiusMeters);
        return new Projection(
                round2(distance),
                ratio,
                PresenceDotPresentation.distanceBucket(ratio),
                PresenceDotPresentation.perimeter(ratio),
                round2(bearing),
                relativeBearingDegrees(bearing, orientationDegrees),
                offset.x(),
                offset.y(),
                altitudeDeltaMeters(origin.altitudeMeters(), record.position().altitudeMeters()),
                ageSeconds,
                expiresInSeconds,
                PresenceDotPresentation.freshnessState(ageSeconds, expiresInSeconds));
    }

    record Projection(
            double distanceMeters,
            double distanceRatio,
            String distanceBucket,
            boolean perimeter,
            double bearingDegrees,
            double relativeBearingDegrees,
            double relativeX,
            double relativeY,
            Double altitudeDeltaMeters,
            long ageSeconds,
            long expiresInSeconds,
            String freshnessState) {
        NearbyPresence toNearby(PresenceRecord record, String visibilityReason) {
            return new NearbyPresence(
                    record.userId(),
                    record.displayName(),
                    record.avatarUrl(),
                    record.position(),
                    record.headingDegrees(),
                    record.compassDegrees(),
                    record.visibility(),
                    visibilityReason,
                    record.shareRadiusMeters(),
                    record.statusMessage(),
                    distanceMeters,
                    distanceRatio,
                    distanceBucket,
                    perimeter,
                    bearingDegrees,
                    relativeBearingDegrees,
                    relativeX,
                    relativeY,
                    altitudeDeltaMeters,
                    ageSeconds,
                    expiresInSeconds,
                    freshnessState,
                    record.observedAt(),
                    record.expiresAt());
        }

        MinimapDot toMinimapDot(PresenceRecord record, String visibilityReason) {
            return new MinimapDot(
                    record.userId(),
                    record.displayName(),
                    record.avatarUrl(),
                    record.position(),
                    record.headingDegrees(),
                    record.compassDegrees(),
                    record.visibility(),
                    visibilityReason,
                    record.shareRadiusMeters(),
                    record.statusMessage(),
                    distanceMeters,
                    distanceRatio,
                    distanceBucket,
                    perimeter,
                    bearingDegrees,
                    relativeBearingDegrees,
                    relativeX,
                    relativeY,
                    altitudeDeltaMeters,
                    ageSeconds,
                    expiresInSeconds,
                    freshnessState,
                    record.observedAt(),
                    record.expiresAt());
        }
    }
}
