package tech.kayys.jezaku.validation;

import jakarta.ws.rs.BadRequestException;

public final class RequestParams {
    private RequestParams() {
    }

    public static double normalizePositiveDouble(Double value, double defaultValue, double maxValue, String fieldName) {
        return normalizePositiveDouble(value, defaultValue, maxValue, fieldName,
                fieldName + " must be greater than zero");
    }

    public static double normalizePositiveDouble(
            Double value,
            double defaultValue,
            double maxValue,
            String fieldName,
            String positiveMessage) {
        double normalized = value == null ? defaultValue : value;
        if (!Double.isFinite(normalized) || normalized <= 0.0) {
            throw new BadRequestException(positiveMessage);
        }
        return Math.min(normalized, maxValue);
    }

    public static double normalizePositiveDouble(
            double value,
            double maxValue,
            String fieldName,
            String positiveMessage) {
        return normalizePositiveDouble(value, value, maxValue, fieldName, positiveMessage);
    }

    public static double normalizeBoundedDouble(
            Double value,
            double defaultValue,
            double minValue,
            double maxValue,
            String fieldName) {
        double normalized = value == null ? defaultValue : value;
        return normalizeBoundedDouble(normalized, minValue, maxValue, fieldName);
    }

    public static double normalizeBoundedDouble(double value, double minValue, double maxValue, String fieldName) {
        if (!Double.isFinite(value) || value < minValue || value > maxValue) {
            throw new BadRequestException(fieldName + " must be between "
                    + display(minValue) + " and " + display(maxValue));
        }
        return value;
    }

    public static Double normalizeOptionalBoundedDouble(
            Double value,
            double minValue,
            double maxValue,
            String fieldName) {
        if (value == null) {
            return null;
        }
        return normalizeBoundedDouble(value, minValue, maxValue, fieldName);
    }

    public static int normalizeBoundedInt(Integer value, int defaultValue, int minValue, int maxValue, String fieldName) {
        int normalized = value == null ? defaultValue : value;
        if (normalized < minValue || normalized > maxValue) {
            throw new BadRequestException(fieldName + " must be between " + minValue + " and " + maxValue);
        }
        return normalized;
    }

    public static long normalizeBoundedLong(Long value, long defaultValue, long minValue, long maxValue, String fieldName) {
        long normalized = value == null ? defaultValue : value;
        return normalizeBoundedLong(normalized, minValue, maxValue, fieldName);
    }

    public static long normalizeBoundedLong(long value, long minValue, long maxValue, String fieldName) {
        if (value < minValue || value > maxValue) {
            throw new BadRequestException(fieldName + " must be between " + minValue + " and " + maxValue);
        }
        return value;
    }

    public static int clampInt(Integer value, int defaultValue, int minValue, int maxValue) {
        int normalized = value == null ? defaultValue : value;
        return Math.max(minValue, Math.min(normalized, maxValue));
    }

    private static String display(double value) {
        if (value == Math.rint(value)) {
            return Long.toString((long) value);
        }
        return Double.toString(value);
    }
}
