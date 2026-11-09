package tech.kayys.jezaku.validation;

import jakarta.ws.rs.BadRequestException;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public final class TextParams {
    private TextParams() {
    }

    public static String requireText(String value, String field) {
        String normalized = optionalTrim(value, null);
        if (normalized == null) {
            throw new BadRequestException(field + " is required");
        }
        return normalized;
    }

    public static String requireTextMaxLength(String value, String field, int maxLength) {
        return ensureMaxLength(requireText(value, field), field, maxLength);
    }

    public static String optionalTextMaxLength(String value, String defaultValue, String field, int maxLength) {
        return ensureMaxLength(optionalTrim(value, defaultValue), field, maxLength);
    }

    public static String requireChoice(String value, Set<String> allowed, String field) {
        return requireChoice(value, allowed, field, field + " is not supported");
    }

    public static String requireChoice(String value, Set<String> allowed, String field, String unsupportedMessage) {
        String normalized = requireText(value, field).toLowerCase(Locale.ROOT);
        if (!allowed.contains(normalized)) {
            throw new BadRequestException(unsupportedMessage);
        }
        return normalized;
    }

    public static String optionalChoice(
            String value,
            String defaultValue,
            Set<String> allowed,
            String field,
            String unsupportedMessage) {
        String normalized = optionalTrim(value, defaultValue);
        if (normalized == null) {
            return null;
        }
        normalized = normalized.toLowerCase(Locale.ROOT);
        if (!allowed.contains(normalized)) {
            throw new BadRequestException(unsupportedMessage);
        }
        return normalized;
    }

    public static String optionalTrim(String value, String defaultValue) {
        if (value == null) {
            return defaultValue;
        }
        String normalized = value.trim();
        return normalized.isEmpty() ? defaultValue : normalized;
    }

    public static List<String> normalizeUniqueStrings(List<String> values) {
        if (values == null || values.isEmpty()) {
            return List.of();
        }
        return normalizeUniqueStrings(values, List.of());
    }

    public static List<String> normalizeUniqueStrings(List<String> values, List<String> defaultValue) {
        if (values == null) {
            return defaultValue;
        }
        List<String> normalized = new ArrayList<>();
        for (String value : values) {
            String item = optionalTrim(value, null);
            if (item != null && !normalized.contains(item)) {
                normalized.add(item);
            }
        }
        return List.copyOf(normalized);
    }

    private static String ensureMaxLength(String value, String field, int maxLength) {
        if (value != null && value.length() > maxLength) {
            throw new BadRequestException(field + " must be " + maxLength + " characters or fewer");
        }
        return value;
    }
}
