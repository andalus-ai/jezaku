package tech.kayys.jezaku.spatial;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.spatial.SpatialDtos.AnchorCreateRequest;
import tech.kayys.jezaku.spatial.SpatialDtos.AnchorResponse;
import tech.kayys.jezaku.spatial.SpatialDtos.GeoPoint;
import tech.kayys.jezaku.spatial.SpatialDtos.PlaceDetail;
import tech.kayys.jezaku.spatial.SpatialDtos.PlaceSummary;
import tech.kayys.jezaku.spatial.SpatialDtos.SourceBreakdown;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailCompletionRequest;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailHistoryEntry;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailHistoryResponse;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailHistorySummary;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.round1;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;

@ApplicationScoped
public class SpatialService {
    private static final double DEFAULT_DISTANCE = 0;
    private static final int MAX_HISTORY = 100;

    private final Map<String, AnchorRecord> anchors = new ConcurrentHashMap<>();
    private final Map<String, TrailRecord> trails = new ConcurrentHashMap<>();
    private final Map<String, PlaceRecord> places = new ConcurrentHashMap<>();
    private final Map<String, Set<String>> savedTrailIdsByUser = new ConcurrentHashMap<>();

    public SpatialService() {
        seedPlaces();
        seedAnchors();
    }

    public Uni<List<AnchorResponse>> nearbyAnchors(
            double latitude,
            double longitude,
            double radiusMeters) {
        return Uni.createFrom().item(() -> {
            validateLatLng(latitude, longitude);
            final var radius = normalizeRadius(radiusMeters);
            return anchors.values().stream()
                    .map(anchor -> anchorResponse(
                            anchor,
                            distanceMeters(latitude, longitude, anchor.position.latitude(), anchor.position.longitude())))
                    .filter(anchor -> anchor.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(AnchorResponse::distanceMeters))
                    .toList();
        });
    }

    public Uni<AnchorResponse> createAnchor(AnchorCreateRequest request) {
        return Uni.createFrom().item(() -> {
            final var ownerId = requireText(request.ownerId(), "ownerId");
            final var title = requireText(request.title(), "title");
            final var position = requirePosition(request.position());
            final var visibility = defaultText(request.visibility(), "private").toLowerCase(Locale.ROOT);
            final var id = "anchor_" + UUID.randomUUID();
            final var anchor = new AnchorRecord(
                    id,
                    ownerId,
                    title,
                    defaultText(request.mediaUrl(), ""),
                    position,
                    normalizeDegrees(request.headingDegrees(), "headingDegrees"),
                    visibility,
                    normalizeOptional(request.placeId()),
                    Instant.now());
            anchors.put(id, anchor);
            return anchorResponse(anchor, DEFAULT_DISTANCE);
        });
    }

    public Uni<TrailHistoryEntry> recordTrailCompletion(TrailCompletionRequest request) {
        return Uni.createFrom().item(() -> {
            final var userId = requireText(request.userId(), "userId");
            final var title = defaultText(request.title(), "AR trail");
            final var source = normalizeSource(request.source());
            final var memoryIds = normalizeMemoryIds(request.memoryIds());
            if (memoryIds.size() < 2) {
                throw new BadRequestException("memoryIds must contain at least two stops");
            }
            final var startedAt = requireInstant(request.startedAt(), "startedAt");
            final var finishedAt = requireInstant(request.finishedAt(), "finishedAt");
            if (finishedAt.isBefore(startedAt)) {
                throw new BadRequestException("finishedAt must not be before startedAt");
            }

            final var trail = new TrailRecord(
                    "trail_" + UUID.randomUUID(),
                    userId,
                    title,
                    source,
                    List.copyOf(memoryIds),
                    startedAt,
                    finishedAt,
                    normalizeOptional(request.sourceWallId()));
            trails.put(trail.id, trail);
            return trailEntry(trail);
        });
    }

    public Uni<TrailHistoryResponse> trailHistory(String userId) {
        return Uni.createFrom().item(() -> trailHistoryResponse(requireText(userId, "userId")));
    }

    public Uni<TrailHistoryResponse> clearTrailHistory(String userId) {
        return Uni.createFrom().item(() -> {
            final var normalizedUserId = requireText(userId, "userId");
            final var deletedTrailIds = new LinkedHashSet<String>();
            trails.values().removeIf(trail -> {
                final var shouldDelete = trail.userId.equals(normalizedUserId);
                if (shouldDelete) {
                    deletedTrailIds.add(trail.id);
                }
                return shouldDelete;
            });
            savedTrailIdsByUser.computeIfPresent(normalizedUserId, (ignored, savedTrailIds) -> {
                savedTrailIds.removeAll(deletedTrailIds);
                return savedTrailIds.isEmpty() ? null : savedTrailIds;
            });
            return trailHistoryResponse(normalizedUserId);
        });
    }

    public Uni<TrailHistoryEntry> saveTrail(String userId, String trailId) {
        return Uni.createFrom().item(() -> {
            final var normalizedUserId = requireText(userId, "userId");
            final var normalizedTrailId = requireText(trailId, "trailId");
            final var trail = trailForUser(normalizedUserId, normalizedTrailId);
            savedTrailIdsByUser
                    .computeIfAbsent(normalizedUserId, ignored -> ConcurrentHashMap.newKeySet())
                    .add(normalizedTrailId);
            return trailEntry(trail);
        });
    }

    public Uni<List<TrailHistoryEntry>> savedTrails(String userId) {
        return Uni.createFrom().item(() -> {
            final var normalizedUserId = requireText(userId, "userId");
            final var savedTrailIds = savedTrailIdsByUser.getOrDefault(normalizedUserId, Set.of());
            return userTrails(normalizedUserId).stream()
                    .filter(trail -> savedTrailIds.contains(trail.id))
                    .map(this::trailEntry)
                    .toList();
        });
    }

    public Uni<Void> unsaveTrail(String userId, String trailId) {
        return Uni.createFrom().voidItem()
                .invoke(() -> {
                    final var normalizedUserId = requireText(userId, "userId");
                    final var normalizedTrailId = requireText(trailId, "trailId");
                    trailForUser(normalizedUserId, normalizedTrailId);
                    savedTrailIdsByUser.computeIfPresent(normalizedUserId, (ignored, savedTrailIds) -> {
                        savedTrailIds.remove(normalizedTrailId);
                        return savedTrailIds.isEmpty() ? null : savedTrailIds;
                    });
                });
    }

    public Uni<List<PlaceSummary>> nearbyPlaces(
            double latitude,
            double longitude,
            double radiusMeters) {
        return Uni.createFrom().item(() -> {
            validateLatLng(latitude, longitude);
            final var radius = normalizeRadius(radiusMeters);
            return places.values().stream()
                    .map(place -> placeSummary(
                            place,
                            distanceMeters(latitude, longitude, place.center.latitude(), place.center.longitude())))
                    .filter(place -> place.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(PlaceSummary::distanceMeters))
                    .toList();
        });
    }

    public Uni<PlaceDetail> placeDetail(String placeId) {
        return Uni.createFrom().item(() -> {
            final var normalizedPlaceId = requireText(placeId, "placeId");
            final var place = places.get(normalizedPlaceId);
            if (place == null) {
                throw new NotFoundException("place not found");
            }
            final var placeAnchors = anchors.values().stream()
                    .filter(anchor -> normalizedPlaceId.equals(anchor.placeId))
                    .map(anchor -> anchorResponse(anchor, DEFAULT_DISTANCE))
                    .sorted(Comparator.comparing(AnchorResponse::createdAt).reversed())
                    .toList();
            final var recentTrails = trails.values().stream()
                    .filter(trail -> trailTouchesPlace(trail, normalizedPlaceId))
                    .sorted(Comparator.comparing(TrailRecord::finishedAt).reversed())
                    .limit(10)
                    .map(this::trailEntry)
                    .toList();
            return new PlaceDetail(placeSummary(place, DEFAULT_DISTANCE), placeAnchors, recentTrails);
        });
    }

    private TrailHistoryResponse trailHistoryResponse(String userId) {
        final var userTrails = userTrails(userId).stream()
                .limit(MAX_HISTORY)
                .map(this::trailEntry)
                .toList();
        return new TrailHistoryResponse(userId, summary(userId), userTrails);
    }

    private List<TrailRecord> userTrails(String userId) {
        return trails.values().stream()
                .filter(trail -> trail.userId.equals(userId))
                .sorted(Comparator.comparing(TrailRecord::finishedAt).reversed())
                .toList();
    }

    private TrailHistorySummary summary(String userId) {
        final var userTrails = userTrails(userId);
        var reachedStopCount = 0;
        var totalElapsedSeconds = 0L;
        TrailRecord fastestTrail = null;
        TrailRecord latestTrail = null;
        final var sourceCounts = new LinkedHashMap<String, Integer>();

        for (final var trail : userTrails) {
            reachedStopCount += trail.memoryIds.size();
            totalElapsedSeconds += trail.elapsedSeconds();
            sourceCounts.merge(trail.source, 1, Integer::sum);
            if (fastestTrail == null || trail.elapsedSeconds() < fastestTrail.elapsedSeconds()) {
                fastestTrail = trail;
            }
            if (latestTrail == null || trail.finishedAt.isAfter(latestTrail.finishedAt)) {
                latestTrail = trail;
            }
        }

        final var sources = sourceCounts.entrySet().stream()
                .map(entry -> new SourceBreakdown(entry.getKey(), sourceLabel(entry.getKey()), entry.getValue()))
                .sorted(Comparator
                        .comparingInt(SourceBreakdown::completedTrailCount)
                        .reversed()
                        .thenComparing(SourceBreakdown::source))
                .toList();

        return new TrailHistorySummary(
                userTrails.size(),
                reachedStopCount,
                totalElapsedSeconds,
                fastestTrail == null ? null : fastestTrail.id,
                latestTrail == null ? null : latestTrail.id,
                sources);
    }

    private TrailRecord trailForUser(String userId, String trailId) {
        final var trail = trails.get(trailId);
        if (trail == null || !trail.userId.equals(userId)) {
            throw new NotFoundException("trail not found");
        }
        return trail;
    }

    private AnchorResponse anchorResponse(AnchorRecord anchor, double distanceMeters) {
        return new AnchorResponse(
                anchor.id,
                anchor.ownerId,
                anchor.title,
                anchor.mediaUrl,
                anchor.position,
                anchor.headingDegrees,
                anchor.visibility,
                anchor.placeId,
                roundDistance(distanceMeters),
                anchor.createdAt);
    }

    private TrailHistoryEntry trailEntry(TrailRecord trail) {
        final var savedTrailIds = savedTrailIdsByUser.getOrDefault(trail.userId, Set.of());
        return new TrailHistoryEntry(
                trail.id,
                trail.userId,
                trail.title,
                trail.source,
                sourceLabel(trail.source),
                trail.memoryIds,
                trail.memoryIds.size(),
                trail.elapsedSeconds(),
                trail.startedAt,
                trail.finishedAt,
                trail.sourceWallId,
                savedTrailIds.contains(trail.id));
    }

    private PlaceSummary placeSummary(PlaceRecord place, double distanceMeters) {
        final var anchorCount = (int) anchors.values().stream()
                .filter(anchor -> place.id.equals(anchor.placeId))
                .count();
        final var trailCount = (int) trails.values().stream()
                .filter(trail -> trailTouchesPlace(trail, place.id))
                .count();
        return new PlaceSummary(
                place.id,
                place.name,
                place.category,
                place.center,
                anchorCount,
                trailCount,
                place.wallCount,
                roundDistance(distanceMeters));
    }

    private boolean trailTouchesPlace(TrailRecord trail, String placeId) {
        final var placeAnchorIds = anchors.values().stream()
                .filter(anchor -> placeId.equals(anchor.placeId))
                .map(AnchorRecord::id)
                .collect(java.util.stream.Collectors.toSet());
        return trail.memoryIds.stream().anyMatch(placeAnchorIds::contains);
    }

    private void seedPlaces() {
        places.put("place_bandung_campus", new PlaceRecord(
                "place_bandung_campus",
                "Bandung Campus Walk",
                "campus",
                new GeoPoint(-6.91755, 107.61905, 714.0),
                2));
        places.put("place_rooftop_lane", new PlaceRecord(
                "place_rooftop_lane",
                "Rooftop Lane",
                "social",
                new GeoPoint(-6.91712, 107.61941, 724.0),
                1));
    }

    private void seedAnchors() {
        final var now = Instant.parse("2026-05-29T12:00:00Z");
        seedAnchor(new AnchorRecord(
                "anchor_courtyard",
                "demo-user",
                "Courtyard sketch",
                "https://cdn.jezaku.local/courtyard.jpg",
                new GeoPoint(-6.91755, 107.61905, 714.0),
                56.0,
                "public",
                "place_bandung_campus",
                now.minusSeconds(3600)));
        seedAnchor(new AnchorRecord(
                "anchor_rooftop",
                "demo-user",
                "Rooftop sunset",
                "https://cdn.jezaku.local/rooftop.jpg",
                new GeoPoint(-6.91712, 107.61941, 724.0),
                82.0,
                "friends",
                "place_rooftop_lane",
                now.minusSeconds(2500)));
        seedAnchor(new AnchorRecord(
                "anchor_private",
                "family-user",
                "Family mural",
                "https://cdn.jezaku.local/mural.jpg",
                new GeoPoint(-6.91783, 107.61878, 713.0),
                212.0,
                "private",
                "place_bandung_campus",
                now.minusSeconds(1200)));
    }

    private void seedAnchor(AnchorRecord anchor) {
        anchors.put(anchor.id, anchor);
    }

    private static GeoPoint requirePosition(GeoPoint position) {
        if (position == null) {
            throw new BadRequestException("position is required");
        }
        validateLatLng(position.latitude(), position.longitude());
        return position;
    }

    private static double normalizeRadius(double radiusMeters) {
        return normalizePositiveDouble(radiusMeters, 5_000.0, "radiusMeters", "radiusMeters must be positive");
    }

    private static String requireText(String value, String fieldName) {
        final var normalized = normalizeOptional(value);
        if (normalized == null) {
            throw new BadRequestException(fieldName + " is required");
        }
        return normalized;
    }

    private static Instant requireInstant(Instant value, String fieldName) {
        if (value == null) {
            throw new BadRequestException(fieldName + " is required");
        }
        return value;
    }

    private static String defaultText(String value, String fallback) {
        final var normalized = normalizeOptional(value);
        return normalized == null ? fallback : normalized;
    }

    private static String normalizeOptional(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private static List<String> normalizeMemoryIds(List<String> memoryIds) {
        if (memoryIds == null || memoryIds.isEmpty()) {
            throw new BadRequestException("memoryIds are required");
        }
        final var uniqueIds = new LinkedHashSet<String>();
        for (final var memoryId : memoryIds) {
            final var normalized = normalizeOptional(memoryId);
            if (normalized != null) {
                uniqueIds.add(normalized);
            }
        }
        return new ArrayList<>(uniqueIds);
    }

    private static String normalizeSource(String source) {
        return defaultText(source, "custom")
                .toLowerCase(Locale.ROOT)
                .replace('-', '_')
                .replace(' ', '_');
    }

    private static String sourceLabel(String source) {
        return switch (source) {
            case "nearby" -> "Nearby";
            case "camera" -> "Camera";
            case "discover" -> "Discover";
            case "gallery" -> "Gallery";
            case "search" -> "Search";
            case "virtual_wall" -> "Virtual Wall";
            case "memory_details" -> "Memory Details";
            default -> "Custom";
        };
    }

    private static double roundDistance(double distanceMeters) {
        return round1(distanceMeters);
    }

    private record AnchorRecord(
            String id,
            String ownerId,
            String title,
            String mediaUrl,
            GeoPoint position,
            Double headingDegrees,
            String visibility,
            String placeId,
            Instant createdAt) {
    }

    private record TrailRecord(
            String id,
            String userId,
            String title,
            String source,
            List<String> memoryIds,
            Instant startedAt,
            Instant finishedAt,
            String sourceWallId) {
        long elapsedSeconds() {
            return Math.max(0, Duration.between(startedAt, finishedAt).toSeconds());
        }
    }

    private record PlaceRecord(
            String id,
            String name,
            String category,
            GeoPoint center,
            int wallCount) {
    }
}
