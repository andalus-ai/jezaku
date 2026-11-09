package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFilter;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemorySort;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.HexFormat;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;

/**
 * Normalizes nearby-memory feed pagination and produces opaque cursors for follow-up requests.
 */
final class CameraNearbyMemoryPaging {
    private static final String CURSOR_PREFIX = "nearby-memory:";
    private static final String SCOPED_CURSOR_PREFIX = "nearby-memory:v2:";

    private CameraNearbyMemoryPaging() {
    }

    static Request fromRaw(Integer pageSize, String pageCursor) {
        String cursor = cleanCursor(pageCursor);
        DecodedCursor decoded = decodeCursor(cursor);
        return new Request(
                normalizeBoundedInt(
                        pageSize,
                        CameraSyncContract.DEFAULT_NEARBY_MEMORY_PAGE_SIZE,
                        CameraSyncContract.MIN_NEARBY_MEMORY_PAGE_SIZE,
                        CameraSyncContract.MAX_NEARBY_MEMORY_PAGE_SIZE,
                        "pageSize"),
                decoded.offset(),
                decoded.scope(),
                cursor,
                pageSize != null || cursor != null);
    }

    static int sourceLimit(Integer limitPerLayer, Request request) {
        int requestedLimit = normalizeBoundedInt(
                limitPerLayer,
                CameraSyncContract.DEFAULT_LIMIT_PER_LAYER,
                CameraSyncContract.MIN_LIMIT_PER_LAYER,
                CameraSyncContract.MAX_LIMIT_PER_LAYER,
                "limitPerLayer");
        if (!request.explicit()) {
            return requestedLimit;
        }
        int pagingWindow = request.offset() + request.pageSize() + 1;
        return Math.min(
                CameraSyncContract.MAX_LIMIT_PER_LAYER,
                Math.max(requestedLimit, pagingWindow));
    }

    static String nextCursor(
            int nextOffset,
            CameraContextResponse context,
            CameraNearbyMemoryFilter filter,
            CameraNearbyMemorySort sort) {
        String raw = SCOPED_CURSOR_PREFIX + scope(context, filter, sort) + ":" + nextOffset;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    static void validateScope(
            Request request,
            CameraContextResponse context,
            CameraNearbyMemoryFilter filter,
            CameraNearbyMemorySort sort) {
        if (request.scope() == null) {
            return;
        }
        if (!request.scope().equals(scope(context, filter, sort))) {
            throw new BadRequestException("pageCursor does not match feed context, filters, or sort");
        }
    }

    private static DecodedCursor decodeCursor(String cursor) {
        if (cursor == null) {
            return new DecodedCursor(0, null);
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            if (raw.startsWith(SCOPED_CURSOR_PREFIX)) {
                return decodeScoped(raw.substring(SCOPED_CURSOR_PREFIX.length()));
            }
            if (!raw.startsWith(CURSOR_PREFIX)) {
                throw invalidCursor();
            }
            int offset = Integer.parseInt(raw.substring(CURSOR_PREFIX.length()));
            if (offset < 0) {
                throw invalidCursor();
            }
            return new DecodedCursor(offset, null);
        } catch (IllegalArgumentException ex) {
            throw invalidCursor();
        }
    }

    private static DecodedCursor decodeScoped(String raw) {
        int separator = raw.lastIndexOf(':');
        if (separator <= 0 || separator == raw.length() - 1) {
            throw invalidCursor();
        }
        String scope = raw.substring(0, separator);
        int offset = Integer.parseInt(raw.substring(separator + 1));
        if (offset < 0 || scope.isBlank()) {
            throw invalidCursor();
        }
        return new DecodedCursor(offset, scope);
    }

    private static String scope(
            CameraContextResponse context,
            CameraNearbyMemoryFilter filter,
            CameraNearbyMemorySort sort) {
        CameraNearbyMemoryFilter normalizedFilter = filter == null
                ? CameraNearbyMemoryFilters.defaultFilter()
                : filter;
        CameraNearbyMemorySort normalizedSort = sort == null
                ? CameraNearbyMemorySorts.defaultSort()
                : sort;
        String raw = text(context == null ? null : context.viewerId())
                + "\n" + coordinate(context == null || context.telemetry() == null
                        || context.telemetry().position() == null
                        ? null
                        : context.telemetry().position().latitude())
                + "\n" + coordinate(context == null || context.telemetry() == null
                        || context.telemetry().position() == null
                        ? null
                        : context.telemetry().position().longitude())
                + "\n" + coordinate(context == null || context.telemetry() == null
                        || context.telemetry().position() == null
                        ? null
                        : context.telemetry().position().altitudeMeters())
                + "\n" + coordinate(context == null || context.telemetry() == null
                        ? null
                        : context.telemetry().radiusMeters())
                + "\n" + coordinate(context == null || context.telemetry() == null
                        ? null
                        : context.telemetry().orientationDegrees())
                + "\n" + normalizedFilter.mode()
                + "\n" + text(normalizedFilter.ownerId())
                + "\n" + normalizedFilter.includeNeedsRefinement()
                + "\n" + normalizedSort.field()
                + "\n" + normalizedSort.direction();
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest, 0, 12);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 digest is unavailable", ex);
        }
    }

    private static String text(String value) {
        return value == null ? "" : value;
    }

    private static String coordinate(Double value) {
        return value == null ? "" : Double.toString(value);
    }

    private static BadRequestException invalidCursor() {
        return new BadRequestException("pageCursor is invalid");
    }

    private static String cleanCursor(String pageCursor) {
        if (pageCursor == null || pageCursor.isBlank()) {
            return null;
        }
        return pageCursor.trim();
    }

    record Request(int pageSize, int offset, String scope, String pageCursor, boolean explicit) {
    }

    private record DecodedCursor(int offset, String scope) {
    }
}
