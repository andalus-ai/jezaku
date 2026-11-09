package tech.kayys.jezaku.memory;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchItem;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;
import tech.kayys.jezaku.memory.MemoryDtos.GeoPoint;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchor;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorConfidence;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorHistoryEntry;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorHistoryResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryAnchorUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryCreateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryFeedResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMediaSnapshotUpdateRequest;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMediaSnapshotUpdateResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMinimapCluster;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMinimapDot;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMinimapResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryMinimapSummary;
import tech.kayys.jezaku.memory.MemoryDtos.MemoryResponse;
import tech.kayys.jezaku.memory.MemoryDtos.MiniMapDot;
import tech.kayys.jezaku.spatial.AnchorConfidencePolicy;
import tech.kayys.jezaku.spatial.AnchorConfidencePolicy.AnchorConfidence;

import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static tech.kayys.jezaku.taxonomy.JezakuChoices.VISIBILITIES;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.MEDIA_MODERATION_STATUSES;
import static tech.kayys.jezaku.geo.GeoMath.altitudeDeltaMeters;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceRatio;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.orientationDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeBearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffset;
import static tech.kayys.jezaku.geo.GeoMath.relativeOffsetFromOrientation;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeOptionalBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class MemoryService {
    private static final double DEFAULT_MINIMAP_RADIUS_METERS = 100.0;
    private static final double MAX_RADIUS_METERS = 1_000.0;
    private static final int DEFAULT_MINIMAP_RESULT_LIMIT = 50;
    private static final int MAX_MINIMAP_RESULT_LIMIT = 100;
    private static final double MINIMAP_PERIMETER_DISTANCE_RATIO = 0.85;
    private static final int MINIMAP_CLUSTER_SECTOR_COUNT = 8;
    private static final double MINIMAP_CLUSTER_SECTOR_DEGREES = 360.0 / MINIMAP_CLUSTER_SECTOR_COUNT;
    private static final double MAX_GPS_ACCURACY_METERS = 10_000.0;
    private static final int MAX_MEDIA_SNAPSHOT_BATCH = 100;
    private static final Set<String> ANCHOR_TYPES = Set.of("geo", "visual", "hybrid");
    private static final Set<String> MEMORY_MEDIA_PURPOSES = Set.of("memory_photo", "anchor_media");
    private static final Set<String> MEDIA_STATUSES = Set.of("active", "rejected", "deleted");

    private final MemoryRepository repository;
    private final MemoryMediaResolver mediaResolver;

    @Inject
    public MemoryService(MemoryRepository repository, MemoryMediaResolver mediaResolver) {
        this.repository = repository;
        this.mediaResolver = mediaResolver;
        seed();
    }

    public Uni<MemoryResponse> create(MemoryCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateCreate(request);
            Instant now = Instant.now();
            String id = "memory_" + UUID.randomUUID();
            String visibility = normalizeVisibility(request.visibility());
            String anchorType = anchorType(request.anchorType());
            String ownerId = requireText(request.ownerId(), "ownerId");
            MemoryMediaReference media = mediaFor(request, ownerId, visibility);
            MemoryRecord memory = new MemoryRecord(
                    id,
                    ownerId,
                    media.mediaId(),
                    media.status(),
                    media.moderationStatus(),
                    media.mediaUrl(),
                    media.thumbnailUrl(),
                    optionalTrim(request.caption(), ""),
                    request.position(),
                    normalizeDegrees(request.headingDegrees(), "headingDegrees"),
                    normalizeDegrees(request.compassDegrees(), "compassDegrees"),
                    pitchDegrees(request.pitchDegrees()),
                    rollDegrees(request.rollDegrees()),
                    gpsAccuracyMeters(request.gpsAccuracyMeters()),
                    anchorType,
                    visibility,
                    normalizeTags(request.tags()),
                    optionalTrim(request.placeId(), null),
                    request.capturedAt() == null ? now : request.capturedAt(),
                    now);
            repository.save(memory);
            recordAnchorHistory(memory, memory.ownerId(), "capture", now);
            return toResponse(memory, request.position());
        });
    }

    public Uni<MemoryResponse> get(String id, Double lat, Double lng) {
        return Uni.createFrom().item(() -> {
            MemoryRecord memory = repository.findById(id);
            if (memory == null) {
                throw new NotFoundException("Memory not found: " + id);
            }
            GeoPoint viewer = lat == null || lng == null ? memory.position() : new GeoPoint(lat, lng, null);
            return toResponse(memory, viewer);
        });
    }

    public Uni<MemoryResponse> updateAnchor(String id, MemoryAnchorUpdateRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String ownerId = requireText(request.ownerId(), "ownerId");
            MemoryRecord existing = repository.findById(id);
            if (existing == null) {
                throw new NotFoundException("Memory not found: " + id);
            }
            if (!existing.ownerId().equals(ownerId)) {
                throw new ForbiddenException("Only the memory owner can update the anchor");
            }
            GeoPoint position = request.position() == null ? existing.position() : validatedPosition(request.position());
            MemoryRecord updated = new MemoryRecord(
                    existing.id(),
                    existing.ownerId(),
                    existing.mediaId(),
                    existing.mediaStatus(),
                    existing.moderationStatus(),
                    existing.mediaUrl(),
                    existing.thumbnailUrl(),
                    existing.caption(),
                    position,
                    request.headingDegrees() == null
                            ? existing.headingDegrees()
                            : normalizeDegrees(request.headingDegrees(), "headingDegrees"),
                    request.compassDegrees() == null
                            ? existing.compassDegrees()
                            : normalizeDegrees(request.compassDegrees(), "compassDegrees"),
                    request.pitchDegrees() == null ? existing.pitchDegrees() : pitchDegrees(request.pitchDegrees()),
                    request.rollDegrees() == null ? existing.rollDegrees() : rollDegrees(request.rollDegrees()),
                    request.gpsAccuracyMeters() == null
                            ? existing.gpsAccuracyMeters()
                            : gpsAccuracyMeters(request.gpsAccuracyMeters()),
                    request.anchorType() == null ? existing.anchorType() : anchorType(request.anchorType()),
                    existing.visibility(),
                    existing.tags(),
                    existing.placeId(),
                    existing.capturedAt(),
                    existing.createdAt());
            repository.save(updated);
            recordAnchorHistory(updated, ownerId, "refinement", Instant.now());
            return toResponse(updated, updated.position());
        });
    }

    public Uni<MemoryAnchorHistoryResponse> anchorHistory(String id, String ownerId) {
        return Uni.createFrom().item(() -> {
            MemoryRecord memory = repository.findById(id);
            if (memory == null) {
                throw new NotFoundException("Memory not found: " + id);
            }
            String normalizedOwnerId = requireText(ownerId, "ownerId");
            if (!memory.ownerId().equals(normalizedOwnerId)) {
                throw new ForbiddenException("Only the memory owner can view anchor history");
            }
            List<MemoryAnchorHistoryEntry> events = repository.anchorHistory(id).stream()
                    .map(this::toHistoryEntry)
                    .toList();
            return new MemoryAnchorHistoryResponse(id, events.size(), events);
        });
    }

    public Uni<List<MiniMapDot>> nearbyDots(double lat, double lng, Double radiusMeters, String excludeOwnerId) {
        return Uni.createFrom().item(() -> {
            validateLatLng(lat, lng);
            GeoPoint origin = new GeoPoint(lat, lng, null);
            double radius = normalizeRadius(radiusMeters);
            String excludedOwner = optionalTrim(excludeOwnerId, null);
            return repository.findAll().stream()
                    .filter(this::publicVisible)
                    .filter(memory -> excludedOwner == null || !memory.ownerId().equals(excludedOwner))
                    .map(memory -> toDot(memory, origin, radius))
                    .filter(dot -> dot.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(MiniMapDot::distanceMeters))
                    .toList();
        });
    }

    public Uni<MemoryMinimapResponse> minimap(
            double lat,
            double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double radiusMeters,
            String excludeOwnerId,
            Integer limit) {
        return Uni.createFrom().item(() -> {
            validateLatLng(lat, lng);
            GeoPoint origin = new GeoPoint(lat, lng, altitudeMeters);
            Double heading = normalizeDegrees(headingDegrees, "headingDegrees");
            Double compass = normalizeDegrees(compassDegrees, "compassDegrees");
            double orientation = orientationDegrees(heading, compass);
            double radius = normalizeRadius(radiusMeters);
            int normalizedLimit = normalizeMinimapLimit(limit);
            String excludedOwner = optionalTrim(excludeOwnerId, null);
            List<MemoryMinimapDot> available = repository.findAll().stream()
                    .filter(this::publicVisible)
                    .filter(memory -> excludedOwner == null || !memory.ownerId().equals(excludedOwner))
                    .map(memory -> toMinimapDot(memory, origin, orientation, radius))
                    .filter(dot -> dot.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(MemoryMinimapDot::distanceMeters))
                    .toList();
            List<MemoryMinimapDot> dots = available.stream()
                    .limit(normalizedLimit)
                    .toList();
            List<MemoryMinimapCluster> clusters = minimapClusters(dots, radius);
            return new MemoryMinimapResponse(
                    origin,
                    heading,
                    compass,
                    orientation,
                    radius,
                    excludedOwner,
                    dots.size(),
                    available.size(),
                    available.size() > dots.size(),
                    minimapSummary(dots, clusters),
                    clusters,
                    dots);
        });
    }

    public Uni<MemoryFeedResponse> userMemories(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<MemoryResponse> result = repository.findAll().stream()
                    .filter(memory -> memory.ownerId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(MemoryRecord::capturedAt).reversed())
                    .map(memory -> toResponse(memory, memory.position()))
                    .toList();
            return new MemoryFeedResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<List<MemoryResponse>> feed(Double lat, Double lng) {
        return Uni.createFrom().item(() -> {
            GeoPoint viewer = lat == null || lng == null ? null : new GeoPoint(lat, lng, null);
            return repository.findAll().stream()
                    .filter(this::publicVisible)
                    .sorted(Comparator.comparing(MemoryRecord::capturedAt).reversed())
                    .map(memory -> toResponse(memory, viewer == null ? memory.position() : viewer))
                    .toList();
        });
    }

    public Uni<MemoryMediaSnapshotUpdateResponse> updateMediaSnapshot(
            String mediaId,
            MemoryMediaSnapshotUpdateRequest request) {
        return Uni.createFrom().item(() -> {
            String normalizedMediaId = requireText(mediaId, "mediaId");
            String mediaStatus = normalizeMediaStatus(request);
            String moderationStatus = normalizeModerationStatus(request);
            return applyMediaSnapshot(normalizedMediaId, mediaStatus, moderationStatus);
        });
    }

    public Uni<MemoryMediaSnapshotApplyResponse<MemoryMediaSnapshotUpdateResponse>> updateMediaSnapshots(
            MemoryMediaSnapshotBatchRequest request) {
        return Uni.createFrom().item(() -> {
            List<MemoryMediaSnapshotBatchItem> snapshots = normalizeBatchRequest(request);
            Map<String, NormalizedMediaSnapshot> latestByMediaId = new LinkedHashMap<>();
            for (MemoryMediaSnapshotBatchItem item : snapshots) {
                NormalizedMediaSnapshot snapshot = normalizeBatchItem(item);
                latestByMediaId.merge(snapshot.mediaId(), snapshot, this::latestSnapshot);
            }
            List<MemoryMediaSnapshotUpdateResponse> results = latestByMediaId.values().stream()
                    .map(this::applyMediaSnapshot)
                    .toList();
            int appliedCount = (int) results.stream()
                    .filter(MemoryMediaSnapshotUpdateResponse::applied)
                    .count();
            int staleCount = (int) results.stream()
                    .filter(MemoryMediaSnapshotUpdateResponse::stale)
                    .count();
            int totalUpdatedCount = results.stream()
                    .mapToInt(MemoryMediaSnapshotUpdateResponse::updatedCount)
                    .sum();
            Long lastAppliedSequence = results.stream()
                    .filter(MemoryMediaSnapshotUpdateResponse::applied)
                    .map(MemoryMediaSnapshotUpdateResponse::sequence)
                    .filter(sequence -> sequence != null)
                    .max(Long::compareTo)
                    .orElse(null);
            List<String> unmatchedMediaIds = results.stream()
                    .filter(MemoryMediaSnapshotUpdateResponse::applied)
                    .filter(result -> result.updatedCount() == 0)
                    .map(MemoryMediaSnapshotUpdateResponse::mediaId)
                    .toList();
            List<String> staleMediaIds = results.stream()
                    .filter(MemoryMediaSnapshotUpdateResponse::stale)
                    .map(MemoryMediaSnapshotUpdateResponse::mediaId)
                    .toList();
            return new MemoryMediaSnapshotApplyResponse<>(
                    snapshots.size(),
                    appliedCount,
                    staleCount,
                    totalUpdatedCount,
                    lastAppliedSequence,
                    unmatchedMediaIds,
                    staleMediaIds,
                    results);
        });
    }

    public Uni<Void> delete(String id) {
        return Uni.createFrom().item(() -> {
            if (!repository.deleteById(id)) {
                throw new NotFoundException("Memory not found: " + id);
            }
            return null;
        });
    }

    private void seed() {
        Instant now = Instant.now();
        addSeed(new MemoryRecord(
                "memory_seed_courtyard",
                "user_current",
                "media_seed_courtyard",
                "active",
                "approved",
                "https://cdn.jezaku.local/media/seed/courtyard.jpg",
                "https://cdn.jezaku.local/memories/courtyard-thumb.jpg",
                "Morning light near the campus path",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                42.0,
                42.0,
                -4.0,
                1.0,
                3.8,
                "geo",
                "public",
                List.of("campus", "trail"),
                "place_bandung_campus",
                now.minusSeconds(480),
                now.minusSeconds(460)));
        addSeed(new MemoryRecord(
                "memory_seed_rooftop",
                "user_rooftop",
                "media_seed_rooftop",
                "active",
                "approved",
                "https://cdn.jezaku.local/media/seed/rooftop.webp",
                "https://cdn.jezaku.local/memories/rooftop-thumb.jpg",
                "Skyline marker beside the wall",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                87.0,
                87.0,
                -8.5,
                0.5,
                4.2,
                "geo",
                "public",
                List.of("photo", "rooftop"),
                "place_rooftop_lane",
                now.minusSeconds(360),
                now.minusSeconds(350)));
        addSeed(new MemoryRecord(
                "memory_seed_reviewed",
                "user_reviewed",
                "media_seed_reviewed",
                "active",
                "approved",
                "https://cdn.jezaku.local/media/seed/reviewed.jpg",
                "https://cdn.jezaku.local/memories/reviewed-thumb.jpg",
                "Moderation sync memory",
                new GeoPoint(-6.890640, 107.610900, 744.1),
                62.0,
                62.0,
                -5.0,
                0.5,
                4.4,
                "geo",
                "public",
                List.of("reviewed", "moderation"),
                "place_review_lane",
                now.minusSeconds(330),
                now.minusSeconds(320)));
        addSeed(new MemoryRecord(
                "memory_seed_stale_guard",
                "user_stale_guard",
                "media_seed_stale_guard",
                "active",
                "approved",
                "https://cdn.jezaku.local/media/seed/stale-guard.jpg",
                "https://cdn.jezaku.local/memories/stale-guard-thumb.jpg",
                "Stale sync guard memory",
                new GeoPoint(-6.890660, 107.610930, 744.3),
                64.0,
                64.0,
                -5.5,
                0.4,
                4.1,
                "geo",
                "public",
                List.of("reviewed", "stale-guard"),
                "place_review_lane",
                now.minusSeconds(315),
                now.minusSeconds(305)));
        addSeed(new MemoryRecord(
                "memory_seed_private",
                "user_private",
                null,
                "external",
                "unverified",
                "https://cdn.jezaku.local/memories/private.jpg",
                "https://cdn.jezaku.local/memories/private-thumb.jpg",
                "Only visible to owner",
                new GeoPoint(-6.890700, 107.610860, 741.8),
                180.0,
                181.0,
                null,
                null,
                18.0,
                "geo",
                "private",
                List.of("private"),
                "place_bandung_campus",
                now.minusSeconds(300),
                now.minusSeconds(290)));
        addSeed(new MemoryRecord(
                "memory_seed_far",
                "user_far",
                null,
                "external",
                "unverified",
                "https://cdn.jezaku.local/memories/far.jpg",
                "https://cdn.jezaku.local/memories/far-thumb.jpg",
                "Outside the minimap radius",
                new GeoPoint(-6.893100, 107.613300, 739.2),
                12.0,
                12.0,
                null,
                null,
                25.0,
                "geo",
                "public",
                List.of("far"),
                null,
                now.minusSeconds(240),
                now.minusSeconds(230)));
    }

    private void addSeed(MemoryRecord memory) {
        repository.save(memory);
        recordAnchorHistory(memory, memory.ownerId(), "seed", memory.createdAt());
    }

    private MemoryResponse toResponse(MemoryRecord memory, GeoPoint origin) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(),
                memory.position().latitude(), memory.position().longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(),
                memory.position().latitude(), memory.position().longitude());
        return new MemoryResponse(
                memory.id(),
                memory.ownerId(),
                memory.mediaId(),
                memory.mediaStatus(),
                memory.moderationStatus(),
                memoryAttachable(memory),
                publicMemoryEligible(memory),
                memory.mediaUrl(),
                memory.thumbnailUrl(),
                memory.caption(),
                memory.position(),
                memory.headingDegrees(),
                memory.compassDegrees(),
                anchor(memory),
                memory.visibility(),
                memory.tags(),
                memory.placeId(),
                memory.capturedAt(),
                memory.createdAt(),
                round2(distance),
                round2(bearing));
    }

    private MiniMapDot toDot(MemoryRecord memory, GeoPoint origin, double radiusMeters) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(),
                memory.position().latitude(), memory.position().longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(),
                memory.position().latitude(), memory.position().longitude());
        var offset = relativeOffset(distance, bearing, radiusMeters);
        return new MiniMapDot(
                memory.id(),
                memory.ownerId(),
                memory.mediaId(),
                memory.mediaStatus(),
                memory.moderationStatus(),
                memoryAttachable(memory),
                publicMemoryEligible(memory),
                memory.thumbnailUrl(),
                anchor(memory),
                memory.position(),
                round2(distance),
                round2(bearing),
                offset.x(),
                offset.y(),
                memory.capturedAt());
    }

    private MemoryMinimapDot toMinimapDot(MemoryRecord memory, GeoPoint origin, double orientation, double radiusMeters) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(),
                memory.position().latitude(), memory.position().longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(),
                memory.position().latitude(), memory.position().longitude());
        double relativeBearing = relativeBearingDegrees(bearing, orientation);
        var offset = relativeOffsetFromOrientation(distance, bearing, orientation, radiusMeters);
        return new MemoryMinimapDot(
                memory.id(),
                memory.ownerId(),
                memory.mediaId(),
                memory.mediaStatus(),
                memory.moderationStatus(),
                memoryAttachable(memory),
                publicMemoryEligible(memory),
                memory.mediaUrl(),
                memory.thumbnailUrl(),
                memory.caption(),
                memory.position(),
                memory.headingDegrees(),
                memory.compassDegrees(),
                anchor(memory),
                memory.tags(),
                memory.placeId(),
                round2(distance),
                distanceRatio(distance, radiusMeters),
                distanceRatio(distance, radiusMeters) >= MINIMAP_PERIMETER_DISTANCE_RATIO,
                round2(bearing),
                relativeBearing,
                offset.x(),
                offset.y(),
                altitudeDeltaMeters(origin.altitudeMeters(), memory.position().altitudeMeters()),
                memory.capturedAt());
    }

    private MemoryMinimapSummary minimapSummary(
            List<MemoryMinimapDot> dots,
            List<MemoryMinimapCluster> clusters) {
        return new MemoryMinimapSummary(
                dots.size(),
                clusters.size(),
                (int) dots.stream().filter(MemoryMinimapDot::perimeter).count(),
                (int) dots.stream().filter(dot -> dot.anchor() != null && dot.anchor().arReady()).count(),
                dots.stream()
                        .map(MemoryMinimapDot::distanceMeters)
                        .min(Double::compareTo)
                        .orElse(null),
                dots.stream()
                        .map(MemoryMinimapDot::distanceMeters)
                        .max(Double::compareTo)
                        .orElse(null));
    }

    private List<MemoryMinimapCluster> minimapClusters(List<MemoryMinimapDot> dots, double radiusMeters) {
        return dots.stream()
                .collect(java.util.stream.Collectors.groupingBy(
                        this::minimapClusterSector,
                        java.util.TreeMap::new,
                        java.util.stream.Collectors.toList()))
                .entrySet()
                .stream()
                .map(entry -> minimapCluster(entry.getKey(), entry.getValue(), radiusMeters))
                .toList();
    }

    private int minimapClusterSector(MemoryMinimapDot dot) {
        int sector = (int) Math.floor(dot.relativeBearingDegrees() / MINIMAP_CLUSTER_SECTOR_DEGREES);
        return Math.min(MINIMAP_CLUSTER_SECTOR_COUNT - 1, Math.max(0, sector));
    }

    private MemoryMinimapCluster minimapCluster(
            int sectorIndex,
            List<MemoryMinimapDot> dots,
            double radiusMeters) {
        MemoryMinimapDot representative = dots.stream()
                .min(Comparator.comparingDouble(MemoryMinimapDot::distanceMeters))
                .orElseThrow();
        double startBearing = sectorIndex * MINIMAP_CLUSTER_SECTOR_DEGREES;
        double endBearing = (sectorIndex + 1) * MINIMAP_CLUSTER_SECTOR_DEGREES;
        double centerBearing = startBearing + (MINIMAP_CLUSTER_SECTOR_DEGREES / 2.0);
        boolean hasPerimeterDot = dots.stream().anyMatch(MemoryMinimapDot::perimeter);
        double clusterDistance = (hasPerimeterDot
                ? 1.0
                : dots.stream()
                        .mapToDouble(MemoryMinimapDot::distanceRatio)
                        .average()
                        .orElse(0.0)) * radiusMeters;
        var offset = relativeOffset(clusterDistance, centerBearing, radiusMeters);
        return new MemoryMinimapCluster(
                sectorIndex,
                round2(startBearing),
                round2(endBearing),
                round2(centerBearing),
                dots.size(),
                (int) dots.stream().filter(MemoryMinimapDot::perimeter).count(),
                (int) dots.stream().filter(dot -> dot.anchor() != null && dot.anchor().arReady()).count(),
                dots.stream()
                        .map(MemoryMinimapDot::distanceMeters)
                        .min(Double::compareTo)
                        .orElse(0.0),
                dots.stream()
                        .map(MemoryMinimapDot::distanceMeters)
                        .max(Double::compareTo)
                        .orElse(0.0),
                offset.x(),
                offset.y(),
                representative.id(),
                representative.mediaId(),
                representative.thumbnailUrl());
    }

    private void validateCreate(MemoryCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.ownerId(), "ownerId");
        if (request.position() == null) {
            throw new BadRequestException("position is required");
        }
        validatedPosition(request.position());
        normalizeVisibility(request.visibility());
    }

    private MemoryMediaReference mediaFor(MemoryCreateRequest request, String ownerId, String visibility) {
        String mediaId = optionalTrim(request.mediaId(), null);
        if (mediaId == null) {
            String mediaUrl = requireText(request.mediaUrl(), "mediaUrl");
            return new MemoryMediaReference(
                    null,
                    ownerId,
                    mediaUrl,
                    optionalTrim(request.thumbnailUrl(), mediaUrl),
                    "external",
                    "unverified",
                    "external");
        }

        MemoryMediaReference media = mediaResolver.resolve(mediaId);
        if (media == null) {
            throw new NotFoundException("Media not found: " + mediaId);
        }
        if (!media.ownerId().equals(ownerId)) {
            throw new ForbiddenException("Media owner mismatch");
        }
        if (!"active".equals(media.status())) {
            throw new BadRequestException("media must be active");
        }
        if (!MEMORY_MEDIA_PURPOSES.contains(media.purpose())) {
            throw new BadRequestException("media purpose must be memory_photo or anchor_media");
        }
        if ("public".equals(visibility) && !"approved".equals(media.moderationStatus())) {
            throw new BadRequestException("public memory media must be approved");
        }
        return media;
    }

    private GeoPoint validatedPosition(GeoPoint position) {
        validateLatLng(position.latitude(), position.longitude());
        return position;
    }

    private String normalizeMediaStatus(MemoryMediaSnapshotUpdateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        return normalizeMediaStatus(request.mediaStatus());
    }

    private String normalizeModerationStatus(MemoryMediaSnapshotUpdateRequest request) {
        return normalizeModerationStatus(request.moderationStatus());
    }

    private String normalizeMediaStatus(String value) {
        return requireChoice(value, MEDIA_STATUSES, "mediaStatus");
    }

    private String normalizeModerationStatus(String value) {
        return requireChoice(value, MEDIA_MODERATION_STATUSES, "moderationStatus");
    }

    private List<MemoryMediaSnapshotBatchItem> normalizeBatchRequest(MemoryMediaSnapshotBatchRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        if (request.snapshots() == null || request.snapshots().isEmpty()) {
            throw new BadRequestException("snapshots must not be empty");
        }
        if (request.snapshots().size() > MAX_MEDIA_SNAPSHOT_BATCH) {
            throw new BadRequestException("snapshots must contain at most " + MAX_MEDIA_SNAPSHOT_BATCH + " items");
        }
        return request.snapshots();
    }

    private NormalizedMediaSnapshot normalizeBatchItem(MemoryMediaSnapshotBatchItem item) {
        if (item == null) {
            throw new BadRequestException("snapshot item is required");
        }
        Long sequence = item.sequence();
        if (sequence != null && sequence < 0L) {
            throw new BadRequestException("sequence must be greater than or equal to zero");
        }
        return new NormalizedMediaSnapshot(
                requireText(item.mediaId(), "mediaId"),
                normalizeMediaStatus(item.mediaStatus()),
                normalizeModerationStatus(item.moderationStatus()),
                sequence);
    }

    private NormalizedMediaSnapshot latestSnapshot(
            NormalizedMediaSnapshot existing,
            NormalizedMediaSnapshot candidate) {
        if (existing.sequence() != null && candidate.sequence() != null) {
            return candidate.sequence() >= existing.sequence() ? candidate : existing;
        }
        return candidate;
    }

    private MemoryMediaSnapshotUpdateResponse applyMediaSnapshot(NormalizedMediaSnapshot snapshot) {
        Long sequence = snapshot.sequence();
        Long previousSequence = null;
        if (sequence != null) {
            MemoryMediaSnapshotProgressRecord progress = repository.findMediaSnapshotProgress(snapshot.mediaId());
            previousSequence = progress == null ? null : progress.lastSequence();
            if (previousSequence != null && sequence < previousSequence) {
                return skippedMediaSnapshot(snapshot.mediaId(), sequence, previousSequence, true);
            }
            if (previousSequence != null && sequence.equals(previousSequence)) {
                return skippedMediaSnapshot(snapshot.mediaId(), sequence, previousSequence, false);
            }
        }

        MemoryMediaSnapshotUpdateResponse response = applyMediaSnapshot(
                snapshot.mediaId(),
                snapshot.mediaStatus(),
                snapshot.moderationStatus(),
                sequence,
                previousSequence,
                true,
                false);
        if (sequence != null) {
            repository.saveMediaSnapshotProgress(new MemoryMediaSnapshotProgressRecord(
                    snapshot.mediaId(),
                    sequence,
                    Instant.now()));
        }
        return response;
    }

    private MemoryMediaSnapshotUpdateResponse applyMediaSnapshot(
            String mediaId,
            String mediaStatus,
            String moderationStatus) {
        return applyMediaSnapshot(mediaId, mediaStatus, moderationStatus, null, null, true, false);
    }

    private MemoryMediaSnapshotUpdateResponse applyMediaSnapshot(
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            Long sequence,
            Long previousSequence,
            boolean applied,
            boolean stale) {
        List<MemoryRecord> updated = repository.findAll().stream()
                .filter(memory -> mediaId.equals(memory.mediaId()))
                .map(memory -> memory.withMediaSnapshot(mediaStatus, moderationStatus))
                .peek(repository::save)
                .toList();
        List<MemoryResponse> memories = updated.stream()
                .sorted(Comparator.comparing(MemoryRecord::capturedAt).reversed())
                .map(memory -> toResponse(memory, memory.position()))
                .toList();
        return new MemoryMediaSnapshotUpdateResponse(
                mediaId,
                sequence,
                previousSequence,
                applied,
                stale,
                memories.size(),
                memories);
    }

    private MemoryMediaSnapshotUpdateResponse skippedMediaSnapshot(
            String mediaId,
            Long sequence,
            Long previousSequence,
            boolean stale) {
        return new MemoryMediaSnapshotUpdateResponse(
                mediaId,
                sequence,
                previousSequence,
                false,
                stale,
                0,
                List.of());
    }

    private boolean publicVisible(MemoryRecord memory) {
        return "public".equals(memory.visibility())
                && (memory.mediaId() == null || publicMemoryEligible(memory));
    }

    private boolean memoryAttachable(MemoryRecord memory) {
        return memory.mediaId() != null && "active".equals(memory.mediaStatus());
    }

    private boolean publicMemoryEligible(MemoryRecord memory) {
        return memoryAttachable(memory) && "approved".equals(memory.moderationStatus());
    }

    private String normalizeVisibility(String value) {
        return optionalChoice(value, "public", VISIBILITIES, "visibility", "visibility must be public, friends, or private");
    }

    private String anchorType(String value) {
        return optionalChoice(value, "geo", ANCHOR_TYPES, "anchorType", "anchorType must be geo, visual, or hybrid");
    }

    private Double pitchDegrees(Double value) {
        return normalizeOptionalBoundedDouble(value, -90.0, 90.0, "pitchDegrees");
    }

    private Double rollDegrees(Double value) {
        return normalizeOptionalBoundedDouble(value, -180.0, 180.0, "rollDegrees");
    }

    private Double gpsAccuracyMeters(Double value) {
        return normalizeOptionalBoundedDouble(value, 0.1, MAX_GPS_ACCURACY_METERS, "gpsAccuracyMeters");
    }

    private MemoryAnchor anchor(MemoryRecord memory) {
        List<MemoryAnchorHistoryRecord> history = repository.anchorHistory(memory.id());
        MemoryAnchorHistoryRecord latest = history.isEmpty() ? null : history.getLast();
        if (latest == null) {
            return anchor(memory, 0, "unknown", memory.createdAt());
        }
        return anchor(memory, latest.revision(), latest.source(), latest.recordedAt());
    }

    private MemoryAnchor anchor(MemoryRecord memory, int revision, String source, Instant updatedAt) {
        MemoryAnchorConfidence confidence = anchorConfidence(memory);
        return new MemoryAnchor(
                memory.anchorType(),
                confidence.level(),
                !"low".equals(confidence.level()),
                revision,
                source,
                updatedAt,
                memory.position(),
                memory.headingDegrees(),
                memory.compassDegrees(),
                memory.pitchDegrees(),
                memory.rollDegrees(),
                memory.gpsAccuracyMeters(),
                confidence);
    }

    private void recordAnchorHistory(MemoryRecord memory, String actorUserId, String source, Instant recordedAt) {
        int revision = repository.anchorHistory(memory.id()).size() + 1;
        repository.saveAnchorHistory(new MemoryAnchorHistoryRecord(
                "memory_anchor_event_" + UUID.randomUUID(),
                memory.id(),
                revision,
                actorUserId,
                source,
                anchor(memory, revision, source, recordedAt),
                recordedAt));
    }

    private MemoryAnchorHistoryEntry toHistoryEntry(MemoryAnchorHistoryRecord event) {
        return new MemoryAnchorHistoryEntry(
                event.eventId(),
                event.memoryId(),
                event.revision(),
                event.actorUserId(),
                event.source(),
                event.anchor(),
                event.recordedAt());
    }

    private MemoryAnchorConfidence anchorConfidence(MemoryRecord memory) {
        AnchorConfidence confidence = AnchorConfidencePolicy.evaluate(
                memory.anchorType(),
                memory.position().altitudeMeters() != null,
                memory.headingDegrees(),
                memory.compassDegrees(),
                memory.pitchDegrees(),
                memory.rollDegrees(),
                memory.gpsAccuracyMeters());
        return new MemoryAnchorConfidence(
                confidence.score(),
                confidence.level(),
                confidence.reasons(),
                confidence.recommendedActions());
    }

    private List<String> normalizeTags(List<String> tags) {
        return normalizeUniqueStrings(tags);
    }

    private double normalizeRadius(Double radiusMeters) {
        return normalizePositiveDouble(radiusMeters, DEFAULT_MINIMAP_RADIUS_METERS, MAX_RADIUS_METERS, "radiusMeters");
    }

    private int normalizeMinimapLimit(Integer limit) {
        return normalizeBoundedInt(limit, DEFAULT_MINIMAP_RESULT_LIMIT, 1, MAX_MINIMAP_RESULT_LIMIT, "limit");
    }

    private record NormalizedMediaSnapshot(
            String mediaId,
            String mediaStatus,
            String moderationStatus,
            Long sequence) {
    }

}
