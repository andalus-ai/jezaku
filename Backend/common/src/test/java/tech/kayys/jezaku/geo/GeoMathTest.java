package tech.kayys.jezaku.geo;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static tech.kayys.jezaku.geo.GeoMath.altitudeDeltaMeters;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceRatio;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.orientationDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeBearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffset;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffsetFromOrientation;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;

class GeoMathTest {
    @Test
    void validatesFiniteLatitudeAndLongitudeBounds() {
        assertDoesNotThrow(() -> validateLatLng(-6.890620, 107.610790));

        assertThrows(BadRequestException.class, () -> validateLatLng(Double.NaN, 107.610790));
        assertThrows(BadRequestException.class, () -> validateLatLng(-6.890620, Double.POSITIVE_INFINITY));
        assertThrows(BadRequestException.class, () -> validateLatLng(-91.0, 107.610790));
        assertThrows(BadRequestException.class, () -> validateLatLng(-6.890620, 181.0));
    }

    @Test
    void calculatesNearbyDistanceAndBearingConsistently() {
        double distance = distanceMeters(-6.890620, 107.610790, -6.890580, 107.610970);
        double bearing = bearingDegrees(-6.890620, 107.610790, -6.890580, 107.610970);

        assertTrue(distance > 19.0 && distance < 21.0);
        assertTrue(bearing > 75.0 && bearing < 80.0);
    }

    @Test
    void normalizesDirectionDegreesIntoCompassRange() {
        assertEquals(5.0, normalizeDegrees(725.0));
        assertEquals(345.0, normalizeDegrees(-15.0));
        assertEquals(0.0, normalizeDegrees(360.0));
        assertNull(normalizeDegrees(null));
        assertThrows(BadRequestException.class, () -> normalizeDegrees(Double.POSITIVE_INFINITY, "headingDegrees"));
    }

    @Test
    void mapsBearingToClampedMinimapOffset() {
        GeoMath.RelativeOffset offset = relativeOffset(150.0, 90.0, 100.0);

        assertEquals(1.0, offset.x());
        assertEquals(0.0, offset.y());
    }

    @Test
    void mapsCompassOrientedMinimapOffsets() {
        GeoMath.RelativeOffset offset = relativeOffsetFromOrientation(50.0, 90.0, 90.0, 100.0);

        assertEquals(0.0, offset.x());
        assertEquals(-0.5, offset.y());
        assertEquals(0.5, distanceRatio(50.0, 100.0));
        assertEquals(1.0, distanceRatio(150.0, 100.0));
        assertEquals(270.0, relativeBearingDegrees(0.0, 90.0));
        assertEquals(0.0, relativeBearingDegrees(359.999, 0.0));
    }

    @Test
    void derivesCameraOrientationAndAltitudeDelta() {
        assertEquals(90.0, orientationDegrees(45.0, 90.0));
        assertEquals(45.0, orientationDegrees(45.0, null));
        assertEquals(0.0, orientationDegrees(null, null));
        assertEquals(5.75, altitudeDeltaMeters(100.0, 105.75));
        assertNull(altitudeDeltaMeters(null, 105.75));
        assertNull(altitudeDeltaMeters(100.0, null));
    }
}
