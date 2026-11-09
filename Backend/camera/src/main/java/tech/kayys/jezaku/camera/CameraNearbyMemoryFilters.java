package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFilter;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryItem;

import java.util.Locale;

/**
 * Normalizes and evaluates nearby-memory feed filters shared by query and session endpoints.
 */
final class CameraNearbyMemoryFilters {
    private CameraNearbyMemoryFilters() {
    }

    static CameraNearbyMemoryFilter defaultFilter() {
        return new CameraNearbyMemoryFilter(
                CameraSyncContract.DEFAULT_NEARBY_MEMORY_FEED_MODE,
                null,
                true);
    }

    static CameraNearbyMemoryFilter fromRaw(
            String mode,
            String ownerId,
            Boolean includeNeedsRefinement) {
        String normalizedMode = token(mode, CameraSyncContract.DEFAULT_NEARBY_MEMORY_FEED_MODE);
        if (!CameraSyncContract.SUPPORTED_NEARBY_MEMORY_FEED_MODES.contains(normalizedMode)) {
            throw new BadRequestException("feedMode must be one of "
                    + String.join(", ", CameraSyncContract.SUPPORTED_NEARBY_MEMORY_FEED_MODES));
        }
        return new CameraNearbyMemoryFilter(
                normalizedMode,
                cleanOwnerId(ownerId),
                includeNeedsRefinement == null || includeNeedsRefinement);
    }

    static boolean matches(CameraNearbyMemoryItem item, CameraNearbyMemoryFilter filter) {
        if (filter.ownerId() != null && !filter.ownerId().equals(item.ownerId())) {
            return false;
        }
        if (!filter.includeNeedsRefinement()
                && item.needsAnchorRefinement()
                && !CameraSyncContract.NEARBY_MEMORY_FEED_MODE_NEEDS_REFINEMENT.equals(filter.mode())) {
            return false;
        }
        return switch (filter.mode()) {
            case CameraSyncContract.NEARBY_MEMORY_FEED_MODE_AR_READY -> item.arReady();
            case CameraSyncContract.NEARBY_MEMORY_FEED_MODE_PHOTO_READY -> isPhotoReady(item);
            case CameraSyncContract.NEARBY_MEMORY_FEED_MODE_ATTACHABLE -> Boolean.TRUE.equals(item.memoryAttachable());
            case CameraSyncContract.NEARBY_MEMORY_FEED_MODE_NEEDS_REFINEMENT -> item.needsAnchorRefinement();
            default -> true;
        };
    }

    private static boolean isPhotoReady(CameraNearbyMemoryItem item) {
        return Boolean.TRUE.equals(item.publicMemoryEligible())
                && "active".equals(item.mediaStatus())
                && "approved".equals(item.moderationStatus())
                && ("photo".equals(item.displayMode()) || "ar_photo".equals(item.displayMode()));
    }

    private static String cleanOwnerId(String ownerId) {
        if (ownerId == null || ownerId.isBlank()) {
            return null;
        }
        return ownerId.trim();
    }

    private static String token(String value, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value.trim().toLowerCase(Locale.ROOT).replace('-', '_');
    }
}
