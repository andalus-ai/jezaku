package tech.kayys.jezaku.validation;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static tech.kayys.jezaku.validation.RequestParams.clampInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedLong;
import static tech.kayys.jezaku.validation.RequestParams.normalizeOptionalBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;

class RequestParamsTest {
    @Test
    void defaultsAndCapsPositiveDoubles() {
        assertEquals(100.0, normalizePositiveDouble(null, 100.0, 1_000.0, "radiusMeters"));
        assertEquals(1_000.0, normalizePositiveDouble(5_000.0, 100.0, 1_000.0, "radiusMeters"));
        assertEquals(1_000.0, normalizePositiveDouble(5_000.0, 1_000.0, "radiusMeters",
                "radiusMeters must be positive"));
    }

    @Test
    void rejectsNonFiniteOrNonPositiveDoubles() {
        assertThrows(BadRequestException.class,
                () -> normalizePositiveDouble(0.0, 100.0, 1_000.0, "radiusMeters"));
        assertThrows(BadRequestException.class,
                () -> normalizePositiveDouble(Double.NaN, 100.0, 1_000.0, "radiusMeters"));
    }

    @Test
    void boundsDoublesAndInts() {
        assertEquals(50.0, normalizeBoundedDouble(null, 50.0, 10.0, 500.0, "checkInRadiusMeters"));
        assertEquals(75.0, normalizeBoundedDouble(75.0, 10.0, 500.0, "checkInRadiusMeters"));
        assertEquals(20, normalizeBoundedInt(null, 20, 1, 100, "limit"));
        assertEquals(20L, normalizeBoundedLong(null, 20L, 1L, 100L, "byteSize"));
        assertEquals(75L, normalizeBoundedLong(75L, 1L, 100L, "byteSize"));
        assertEquals(1.27, normalizeOptionalBoundedDouble(1.27, 0.0, 100.0, "speedMetersPerSecond"));
        assertNull(normalizeOptionalBoundedDouble(null, 0.0, 100.0, "speedMetersPerSecond"));

        assertThrows(BadRequestException.class,
                () -> normalizeBoundedDouble(9.0, 10.0, 500.0, "checkInRadiusMeters"));
        assertThrows(BadRequestException.class,
                () -> normalizeBoundedInt(101, 20, 1, 100, "limit"));
        assertThrows(BadRequestException.class,
                () -> normalizeBoundedLong(0L, 1L, 100L, "byteSize"));
        assertThrows(BadRequestException.class,
                () -> normalizeOptionalBoundedDouble(Double.NaN, 0.0, 100.0, "speedMetersPerSecond"));
    }

    @Test
    void clampsIntsForLenientQueryLimits() {
        assertEquals(50, clampInt(null, 50, 1, 100));
        assertEquals(1, clampInt(-5, 50, 1, 100));
        assertEquals(100, clampInt(500, 50, 1, 100));
    }
}
