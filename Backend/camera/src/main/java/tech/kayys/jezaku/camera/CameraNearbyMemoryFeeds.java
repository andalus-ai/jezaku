package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraAnchor;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFeedLinks;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFilter;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFeed;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryItem;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemorySort;

import java.util.List;

/**
 * Projects the camera memories layer into a nearby media feed for gallery and AR detail screens.
 */
final class CameraNearbyMemoryFeeds {
    private CameraNearbyMemoryFeeds() {
    }

    static CameraNearbyMemoryFeed from(CameraContextResponse context) {
        return from(
                context,
                CameraNearbyMemoryFilters.defaultFilter(),
                CameraNearbyMemoryPaging.fromRaw(null, null),
                CameraNearbyMemorySorts.defaultSort());
    }

    static CameraNearbyMemoryFeed from(CameraContextResponse context, CameraNearbyMemoryFilter filter) {
        return from(
                context,
                filter,
                CameraNearbyMemoryPaging.fromRaw(null, null),
                CameraNearbyMemorySorts.defaultSort());
    }

    static CameraNearbyMemoryFeed from(
            CameraContextResponse context,
            CameraNearbyMemoryFilter filter,
            CameraNearbyMemoryPaging.Request paging) {
        return from(context, filter, paging, CameraNearbyMemorySorts.defaultSort());
    }

    static CameraNearbyMemoryFeed from(
            CameraContextResponse context,
            CameraNearbyMemoryFilter filter,
            CameraNearbyMemoryPaging.Request paging,
            CameraNearbyMemorySort sort) {
        CameraLayer layer = memoryLayer(context);
        CameraNearbyMemoryFilter normalizedFilter = filter == null
                ? CameraNearbyMemoryFilters.defaultFilter()
                : filter;
        CameraNearbyMemorySort normalizedSort = sort == null
                ? CameraNearbyMemorySorts.defaultSort()
                : sort;
        CameraNearbyMemoryPaging.Request normalizedPaging = paging == null
                ? CameraNearbyMemoryPaging.fromRaw(null, null)
                : paging;
        List<CameraNearbyMemoryItem> unfilteredItems = layer == null
                ? List.of()
                : layer.dots().stream()
                        .map(CameraNearbyMemoryFeeds::item)
                        .toList();
        List<CameraNearbyMemoryItem> items = unfilteredItems.stream()
                .filter(item -> CameraNearbyMemoryFilters.matches(item, normalizedFilter))
                .sorted(CameraNearbyMemorySorts.comparator(normalizedSort))
                .toList();
        int endExclusive = Math.min(items.size(), normalizedPaging.offset() + normalizedPaging.pageSize());
        List<CameraNearbyMemoryItem> pageItems = normalizedPaging.offset() >= items.size()
                ? List.of()
                : items.subList(normalizedPaging.offset(), endExclusive);
        boolean hasMore = !pageItems.isEmpty()
                && (endExclusive < items.size() || (layer != null && layer.truncated()));
        return new CameraNearbyMemoryFeed(
                context.viewerId(),
                context.telemetry().position(),
                context.telemetry().radiusMeters(),
                pageItems.size(),
                layer == null ? 0 : layer.totalAvailable(),
                layer != null && layer.truncated(),
                normalizedFilter,
                normalizedSort,
                unfilteredItems.size() - items.size(),
                items.size(),
                normalizedPaging.pageSize(),
                hasMore ? CameraNearbyMemoryPaging.nextCursor(
                        endExclusive,
                        context,
                        normalizedFilter,
                        normalizedSort) : null,
                hasMore,
                countArReady(items),
                countLowConfidence(items),
                countNeedsRefinement(items),
                layer == null ? null : layer.source(),
                layer == null ? null : layer.visibility(),
                pageItems,
                new CameraNearbyMemoryFeedLinks(null),
                context.generatedAt());
    }

    static CameraNearbyMemoryFeed withLinks(
            CameraNearbyMemoryFeed feed,
            CameraNearbyMemoryFeedLinks links) {
        return new CameraNearbyMemoryFeed(
                feed.viewerId(),
                feed.center(),
                feed.radiusMeters(),
                feed.count(),
                feed.totalAvailable(),
                feed.truncated(),
                feed.filter(),
                feed.sort(),
                feed.filteredOutCount(),
                feed.matchingCount(),
                feed.pageSize(),
                feed.nextCursor(),
                feed.hasMore(),
                feed.arReadyCount(),
                feed.lowConfidenceCount(),
                feed.needsRefinementCount(),
                feed.source(),
                feed.visibility(),
                feed.items(),
                links,
                feed.generatedAt());
    }

    private static CameraLayer memoryLayer(CameraContextResponse context) {
        if (context == null || context.layers() == null) {
            return null;
        }
        return context.layers().stream()
                .filter(layer -> "memories".equals(layer.layer()))
                .findFirst()
                .orElse(null);
    }

    private static int countArReady(List<CameraNearbyMemoryItem> items) {
        return (int) items.stream()
                .filter(CameraNearbyMemoryItem::arReady)
                .count();
    }

    private static int countLowConfidence(List<CameraNearbyMemoryItem> items) {
        return (int) items.stream()
                .filter(CameraNearbyMemoryFeeds::lowConfidence)
                .count();
    }

    private static int countNeedsRefinement(List<CameraNearbyMemoryItem> items) {
        return (int) items.stream()
                .filter(CameraNearbyMemoryItem::needsAnchorRefinement)
                .count();
    }

    private static boolean lowConfidence(CameraNearbyMemoryItem item) {
        return item.anchor() != null
                && item.anchor().confidence() != null
                && "low".equals(item.anchor().confidence().level());
    }

    private static CameraNearbyMemoryItem item(CameraDot dot) {
        return new CameraNearbyMemoryItem(
                dot.targetId(),
                dot.ownerId(),
                dot.mediaId(),
                dot.title(),
                dot.subtitle(),
                displayMode(dot),
                dot.visibility(),
                dot.visibilityReason(),
                dot.mediaUrl(),
                dot.thumbnailUrl(),
                dot.mediaStatus(),
                dot.moderationStatus(),
                dot.memoryAttachable(),
                dot.publicMemoryEligible(),
                arReady(dot),
                needsAnchorRefinement(dot.anchor()),
                dot.anchor(),
                dot.position(),
                dot.distanceMeters(),
                dot.distanceRatio(),
                dot.distanceBucket(),
                dot.freshnessState(),
                dot.bearingDegrees(),
                dot.relativeBearingDegrees(),
                dot.relativeX(),
                dot.relativeY(),
                dot.altitudeDeltaMeters(),
                dot.eventAt(),
                href(dot),
                dot.actions());
    }

    private static String displayMode(CameraDot dot) {
        if (!Boolean.TRUE.equals(dot.publicMemoryEligible())) {
            return "photo_hint";
        }
        CameraAnchor anchor = dot.anchor();
        if (anchor == null) {
            return "photo";
        }
        return anchor.arReady() ? "ar_photo" : "photo_hint";
    }

    private static boolean arReady(CameraDot dot) {
        return Boolean.TRUE.equals(dot.publicMemoryEligible())
                && dot.anchor() != null
                && dot.anchor().arReady();
    }

    private static boolean needsAnchorRefinement(CameraAnchor anchor) {
        if (anchor == null) {
            return false;
        }
        if (anchor.confidence() != null) {
            return !anchor.confidence().recommendedActions().isEmpty();
        }
        return !anchor.arReady();
    }

    private static String href(CameraDot dot) {
        return dot.actions().stream()
                .filter(action -> "open".equals(action.type()))
                .map(CameraAction::href)
                .findFirst()
                .orElse("/memories/" + dot.targetId());
    }
}
