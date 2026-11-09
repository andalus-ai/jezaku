package tech.kayys.jezaku.validation;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static tech.kayys.jezaku.validation.TimeParams.normalizeQuietHour;

class TimeParamsTest {
    @Test
    void normalizesQuietHoursWithFallback() {
        assertEquals("22:00", normalizeQuietHour(null, "22:00", "quietHoursStart"));
        assertEquals("06:30", normalizeQuietHour(" 06:30 ", "06:00", "quietHoursEnd"));
        assertEquals("00:00", normalizeQuietHour("00:00", "22:00", "quietHoursStart"));
        assertEquals("23:59", normalizeQuietHour("23:59", "22:00", "quietHoursStart"));
    }

    @Test
    void rejectsInvalidQuietHourFormat() {
        BadRequestException error = assertThrows(BadRequestException.class,
                () -> normalizeQuietHour("24:00", "22:00", "quietHoursStart"));
        assertEquals("quietHoursStart must use HH:mm format", error.getMessage());

        assertThrows(BadRequestException.class,
                () -> normalizeQuietHour("9:00", "22:00", "quietHoursStart"));
        assertThrows(BadRequestException.class,
                () -> normalizeQuietHour("22:60", "22:00", "quietHoursStart"));
    }
}
