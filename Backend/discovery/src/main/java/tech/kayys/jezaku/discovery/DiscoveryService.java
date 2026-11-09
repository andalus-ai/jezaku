package tech.kayys.jezaku.discovery;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.discovery.DiscoveryDtos.DiscoveryItem;
import tech.kayys.jezaku.discovery.DiscoveryDtos.DiscoveryListResponse;
import tech.kayys.jezaku.discovery.DiscoveryDtos.FeedbackRequest;
import tech.kayys.jezaku.discovery.DiscoveryDtos.FeedbackResponse;
import tech.kayys.jezaku.discovery.DiscoveryDtos.GeoPoint;
import tech.kayys.jezaku.discovery.DiscoveryDtos.SearchResponse;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.taxonomy.JezakuTargetTypes.DISCOVERABLE_TARGET_TYPES;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class DiscoveryService {
    private static final double MAX_RADIUS_METERS = 5_000.0;
    private static final Set<String> FEEDBACK_ACTIONS = Set.of("viewed", "saved", "hidden", "dismissed");

    private final Map<String, CatalogItem> catalog = new ConcurrentHashMap<>();
    private final Map<String, FeedbackRecord> feedback = new ConcurrentHashMap<>();

    public DiscoveryService() {
        seed();
    }

    public Uni<DiscoveryListResponse> nearby(double lat, double lng, Double radiusMeters, String viewerId, String type) {
        return Uni.createFrom().item(() -> {
            GeoPoint origin = origin(lat, lng);
            double radius = normalizeRadius(radiusMeters);
            String normalizedViewerId = optionalTrim(viewerId, "");
            String targetType = optionalTrim(type, "");
            if (!targetType.isEmpty()) {
                targetType = normalizeTargetType(targetType);
            }
            String typeFilter = targetType;
            List<DiscoveryItem> items = visibleCatalog(normalizedViewerId).stream()
                    .filter(item -> typeFilter.isEmpty() || item.targetType().equals(typeFilter))
                    .map(item -> toItem(item, origin, normalizedViewerId, false))
                    .filter(item -> item.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(DiscoveryItem::score).reversed()
                            .thenComparing(DiscoveryItem::distanceMeters))
                    .toList();
            return new DiscoveryListResponse(normalizedViewerId, radius, items.size(), items);
        });
    }

    public Uni<SearchResponse> search(String query, Double lat, Double lng, Double radiusMeters) {
        return Uni.createFrom().item(() -> {
            String normalizedQuery = optionalTrim(query, "").toLowerCase(Locale.ROOT);
            if (normalizedQuery.length() < 2) {
                throw new BadRequestException("q must contain at least 2 characters");
            }
            GeoPoint origin = lat == null ? defaultOrigin() : origin(lat, lng);
            double radius = normalizeRadius(radiusMeters);
            List<DiscoveryItem> items = catalog.values().stream()
                    .filter(CatalogItem::discoverable)
                    .filter(item -> item.safetyStatus().equals("clear"))
                    .filter(item -> matches(item, normalizedQuery))
                    .map(item -> toItem(item, origin, "", false))
                    .filter(item -> lat == null || item.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(DiscoveryItem::score).reversed())
                    .toList();
            return new SearchResponse(normalizedQuery, items.size(), items);
        });
    }

    public Uni<DiscoveryListResponse> trending(double lat, double lng, Double radiusMeters) {
        return Uni.createFrom().item(() -> {
            GeoPoint origin = origin(lat, lng);
            double radius = normalizeRadius(radiusMeters);
            List<DiscoveryItem> items = catalog.values().stream()
                    .filter(CatalogItem::discoverable)
                    .filter(item -> item.safetyStatus().equals("clear"))
                    .map(item -> toItem(item, origin, "", true))
                    .filter(item -> item.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(DiscoveryItem::score).reversed())
                    .limit(20)
                    .toList();
            return new DiscoveryListResponse("", radius, items.size(), items);
        });
    }

    public Uni<DiscoveryListResponse> forYou(String userId, double lat, double lng, Double radiusMeters) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            GeoPoint origin = origin(lat, lng);
            double radius = normalizeRadius(radiusMeters);
            List<DiscoveryItem> items = visibleCatalog(normalizedUserId).stream()
                    .map(item -> toItem(item, origin, normalizedUserId, false))
                    .filter(item -> item.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(DiscoveryItem::score).reversed()
                            .thenComparing(DiscoveryItem::distanceMeters))
                    .limit(30)
                    .toList();
            return new DiscoveryListResponse(normalizedUserId, radius, items.size(), items);
        });
    }

    public Uni<FeedbackResponse> feedback(FeedbackRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String userId = requireText(request.userId(), "userId");
            String targetType = normalizeTargetType(request.targetType());
            String targetId = requireText(request.targetId(), "targetId");
            String action = normalizeFeedbackAction(request.action());
            Instant now = Instant.now();
            String key = feedbackKey(userId, targetType, targetId);
            FeedbackRecord existing = feedback.get(key);
            FeedbackRecord record = new FeedbackRecord(
                    userId,
                    targetType,
                    targetId,
                    action,
                    existing == null ? now : existing.createdAt(),
                    now);
            feedback.put(key, record);
            return toResponse(record);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        add(new CatalogItem(
                "disc_memory_courtyard",
                "memory",
                "memory_seed_courtyard",
                "Morning Light Courtyard",
                "Public memory near the campus path",
                "https://cdn.jezaku.local/memories/courtyard-thumb.jpg",
                "photo",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                12,
                List.of("campus", "trail", "photo"),
                null,
                "clear",
                true,
                now.minusSeconds(460)));
        add(new CatalogItem(
                "disc_memory_rooftop",
                "memory",
                "memory_seed_rooftop",
                "Rooftop Skyline Marker",
                "Skyline memory beside the virtual wall",
                "https://cdn.jezaku.local/memories/rooftop-thumb.jpg",
                "photo",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                22,
                List.of("rooftop", "compass", "photo"),
                null,
                "clear",
                true,
                now.minusSeconds(350)));
        add(new CatalogItem(
                "disc_event_campus_walk",
                "event",
                "event_seed_campus_walk",
                "Campus Memory Walk",
                "Trail through public photo anchors and AR wall clues",
                "",
                "trail",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                34,
                List.of("trail", "photo", "campus"),
                now.plusSeconds(3_600),
                "clear",
                true,
                now.minusSeconds(900)));
        add(new CatalogItem(
                "disc_event_rooftop_meet",
                "event",
                "event_seed_rooftop_meet",
                "Rooftop Compass Meetup",
                "Small meetup for skyline direction captures",
                "",
                "meetup",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                27,
                List.of("compass", "rooftop"),
                now.plusSeconds(5_400),
                "clear",
                true,
                now.minusSeconds(700)));
        add(new CatalogItem(
                "disc_place_bandung_campus",
                "place",
                "place_bandung_campus",
                "Bandung Campus Walk",
                "A compact route with photo anchors, safe zones, and memory trails",
                "",
                "campus",
                new GeoPoint(-6.890640, 107.610820, 742.0),
                30,
                List.of("campus", "walk", "anchors"),
                null,
                "clear",
                true,
                now.minusSeconds(1_600)));
        add(new CatalogItem(
                "disc_place_rooftop_lane",
                "place",
                "place_rooftop_lane",
                "Rooftop Lane",
                "Vertical route with compass captures and skyline viewpoints",
                "",
                "viewpoint",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                26,
                List.of("rooftop", "compass", "viewpoint"),
                null,
                "clear",
                true,
                now.minusSeconds(1_500)));
        add(new CatalogItem(
                "disc_trail_anchor_loop",
                "trail",
                "trail_anchor_loop",
                "Anchor Loop",
                "Short loop that connects courtyard and rooftop AR anchors",
                "",
                "trail",
                new GeoPoint(-6.890610, 107.610900, 743.0),
                19,
                List.of("trail", "anchor", "ar"),
                null,
                "clear",
                true,
                now.minusSeconds(1_200)));
        add(new CatalogItem(
                "disc_presence_rooftop",
                "presence",
                "user_rooftop",
                "Rooftop Friend Nearby",
                "Live public signal near the virtual wall",
                "https://cdn.jezaku.local/avatars/rooftop.jpg",
                "nearby_user",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                18,
                List.of("nearby", "friend", "rooftop"),
                null,
                "clear",
                true,
                now.minusSeconds(10)));
        add(new CatalogItem(
                "disc_media_pending",
                "media",
                "media_seed_pending",
                "Fresh Marker Pending Review",
                "Media waiting for moderation before discovery",
                "https://cdn.jezaku.local/media/seed/fresh-marker.png",
                "anchor_media",
                new GeoPoint(-6.890700, 107.610860, 741.8),
                41,
                List.of("anchor", "review"),
                null,
                "review",
                false,
                now.minusSeconds(110)));
        add(new CatalogItem(
                "disc_place_far",
                "place",
                "place_far_view",
                "Far Viewpoint",
                "Outside the immediate campus discovery radius",
                "",
                "viewpoint",
                new GeoPoint(-6.893100, 107.613300, 739.2),
                24,
                List.of("viewpoint", "far"),
                null,
                "clear",
                true,
                now.minusSeconds(1_000)));
    }

    private List<CatalogItem> visibleCatalog(String userId) {
        return catalog.values().stream()
                .filter(CatalogItem::discoverable)
                .filter(item -> item.safetyStatus().equals("clear"))
                .filter(item -> !isHidden(userId, item))
                .toList();
    }

    private DiscoveryItem toItem(CatalogItem item, GeoPoint origin, String userId, boolean trending) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(),
                item.position().latitude(), item.position().longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(),
                item.position().latitude(), item.position().longitude());
        double score = score(item, distance, userId, trending);
        return new DiscoveryItem(
                item.itemId(),
                item.targetType(),
                item.targetId(),
                item.title(),
                item.subtitle(),
                item.thumbnailUrl(),
                item.category(),
                item.position(),
                round2(distance),
                round2(bearing),
                round2(score),
                item.engagementScore(),
                item.tags(),
                item.startsAt(),
                item.updatedAt());
    }

    private double score(CatalogItem item, double distanceMeters, String userId, boolean trending) {
        double proximity = Math.max(0.0, 100.0 - (distanceMeters / 8.0));
        double engagement = item.engagementScore() * (trending ? 2.0 : 1.4);
        double freshness = Math.max(0.0, 24.0 - Math.abs(item.updatedAt().until(Instant.now(), java.time.temporal.ChronoUnit.HOURS)));
        double eventBoost = item.startsAt() == null ? 0.0 : 18.0;
        double savedBoost = isSaved(userId, item) ? 25.0 : 0.0;
        return proximity + engagement + freshness + eventBoost + savedBoost;
    }

    private boolean matches(CatalogItem item, String query) {
        return item.title().toLowerCase(Locale.ROOT).contains(query)
                || item.subtitle().toLowerCase(Locale.ROOT).contains(query)
                || item.category().toLowerCase(Locale.ROOT).contains(query)
                || item.tags().stream().anyMatch(tag -> tag.toLowerCase(Locale.ROOT).contains(query));
    }

    private boolean isHidden(String userId, CatalogItem item) {
        if (userId == null || userId.isEmpty()) {
            return false;
        }
        FeedbackRecord record = feedback.get(feedbackKey(userId, item.targetType(), item.targetId()));
        return record != null && ("hidden".equals(record.action()) || "dismissed".equals(record.action()));
    }

    private boolean isSaved(String userId, CatalogItem item) {
        if (userId == null || userId.isEmpty()) {
            return false;
        }
        FeedbackRecord record = feedback.get(feedbackKey(userId, item.targetType(), item.targetId()));
        return record != null && "saved".equals(record.action());
    }

    private void add(CatalogItem item) {
        catalog.put(item.itemId(), item);
    }

    private GeoPoint origin(double lat, double lng) {
        validateLatLng(lat, lng);
        return new GeoPoint(lat, lng, null);
    }

    private GeoPoint defaultOrigin() {
        return new GeoPoint(-6.890620, 107.610790, null);
    }

    private double normalizeRadius(Double radiusMeters) {
        return normalizePositiveDouble(radiusMeters, 500.0, MAX_RADIUS_METERS, "radiusMeters");
    }

    private String normalizeTargetType(String value) {
        return requireChoice(value, DISCOVERABLE_TARGET_TYPES, "targetType");
    }

    private String normalizeFeedbackAction(String value) {
        return requireChoice(value, FEEDBACK_ACTIONS, "action");
    }

    private FeedbackResponse toResponse(FeedbackRecord record) {
        return new FeedbackResponse(
                record.userId(),
                record.targetType(),
                record.targetId(),
                record.action(),
                record.createdAt(),
                record.updatedAt());
    }

    private String feedbackKey(String userId, String targetType, String targetId) {
        return userId + "|" + targetType + "|" + targetId;
    }

    private record CatalogItem(
            String itemId,
            String targetType,
            String targetId,
            String title,
            String subtitle,
            String thumbnailUrl,
            String category,
            GeoPoint position,
            int engagementScore,
            List<String> tags,
            Instant startsAt,
            String safetyStatus,
            boolean discoverable,
            Instant updatedAt) {
    }

    private record FeedbackRecord(
            String userId,
            String targetType,
            String targetId,
            String action,
            Instant createdAt,
            Instant updatedAt) {
    }
}
