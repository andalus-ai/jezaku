package tech.kayys.jezaku.validation;

import jakarta.ws.rs.BadRequestException;

import java.util.regex.Pattern;

import static tech.kayys.jezaku.validation.TextParams.optionalTrim;

public final class TimeParams {
    private static final Pattern QUIET_HOUR = Pattern.compile("([01][0-9]|2[0-3]):[0-5][0-9]");

    private TimeParams() {
    }

    public static String normalizeQuietHour(String value, String fallback, String field) {
        String normalized = optionalTrim(value, fallback);
        if (!QUIET_HOUR.matcher(normalized).matches()) {
            throw new BadRequestException(field + " must use HH:mm format");
        }
        return normalized;
    }
}
