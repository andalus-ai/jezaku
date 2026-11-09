package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryItem;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemorySort;

import java.time.Instant;
import java.util.Comparator;
import java.util.Locale;

/**
 * Normalizes and applies nearby-memory feed ordering for gallery and AR camera surfaces.
 */
final class CameraNearbyMemorySorts {
    private CameraNearbyMemorySorts() {
    }

    static CameraNearbyMemorySort defaultSort() {
        return new CameraNearbyMemorySort(
                CameraSyncContract.DEFAULT_NEARBY_MEMORY_SORT_FIELD,
                CameraSyncContract.DEFAULT_NEARBY_MEMORY_SORT_DIRECTION);
    }

    static CameraNearbyMemorySort fromRaw(String sortBy, String sortDirection) {
        String field = token(sortBy, CameraSyncContract.DEFAULT_NEARBY_MEMORY_SORT_FIELD);
        String direction = token(sortDirection, CameraSyncContract.DEFAULT_NEARBY_MEMORY_SORT_DIRECTION);
        if (!CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_FIELDS.contains(field)) {
            throw new BadRequestException("sortBy must be one of "
                    + String.join(", ", CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_FIELDS));
        }
        if (!CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_DIRECTIONS.contains(direction)) {
            throw new BadRequestException("sortDirection must be one of "
                    + String.join(", ", CameraSyncContract.SUPPORTED_NEARBY_MEMORY_SORT_DIRECTIONS));
        }
        return new CameraNearbyMemorySort(field, direction);
    }

    static Comparator<CameraNearbyMemoryItem> comparator(CameraNearbyMemorySort sort) {
        CameraNearbyMemorySort normalized = sort == null ? defaultSort() : sort;
        Comparator<CameraNearbyMemoryItem> valueComparator = switch (normalized.field()) {
            case CameraSyncContract.NEARBY_MEMORY_SORT_FIELD_CAPTURED_AT -> Comparator.comparing(
                    CameraNearbyMemoryItem::capturedAt,
                    Comparator.nullsLast(Instant::compareTo));
            case CameraSyncContract.NEARBY_MEMORY_SORT_FIELD_BEARING ->
                    Comparator.comparingDouble(CameraNearbyMemoryItem::relativeBearingDegrees);
            default -> Comparator.comparingDouble(CameraNearbyMemoryItem::distanceMeters);
        };
        if (CameraSyncContract.NEARBY_MEMORY_SORT_DIRECTION_DESC.equals(normalized.direction())) {
            valueComparator = valueComparator.reversed();
        }
        return valueComparator
                .thenComparingDouble(CameraNearbyMemoryItem::distanceMeters)
                .thenComparing(CameraNearbyMemoryItem::memoryId);
    }

    private static String token(String value, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value.trim().toLowerCase(Locale.ROOT).replace('-', '_');
    }
}
