package tech.kayys.jezaku.journeys;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.journeys.JourneyDtos.BadgeResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.CheckpointCompleteRequest;
import tech.kayys.jezaku.journeys.JourneyDtos.CheckpointProgress;
import tech.kayys.jezaku.journeys.JourneyDtos.GeoPoint;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyCheckpoint;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyListResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyProgressResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyStartRequest;
import tech.kayys.jezaku.journeys.JourneyDtos.UserBadgesResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.UserJourneysResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.taxonomy.JezakuTargetTypes.JOURNEY_TARGET_TYPES;
import static tech.kayys.jezaku.taxonomy.JezakuChoices.VISIBILITIES;
import static tech.kayys.jezaku.geo.GeoMath.bearingDegrees;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class JourneyService {
    private static final double MAX_RADIUS_METERS = 5_000.0;
    private static final Set<String> CATEGORIES = Set.of("trail", "photo", "safety", "event", "explore");

    private final Map<String, JourneyRecord> journeys = new ConcurrentHashMap<>();
    private final Map<String, SessionRecord> sessions = new ConcurrentHashMap<>();
    private final Map<String, BadgeRecord> badges = new ConcurrentHashMap<>();

    public JourneyService() {
        seed();
    }

    public Uni<JourneyListResponse> list(double lat, double lng, Double radiusMeters, String viewerId, String category) {
        return Uni.createFrom().item(() -> {
            GeoPoint origin = origin(lat, lng);
            double radius = normalizeRadius(radiusMeters);
            String normalizedViewerId = optionalTrim(viewerId, "");
            String normalizedCategory = optionalTrim(category, "");
            if (!normalizedCategory.isEmpty()) {
                normalizedCategory = normalizeCategory(normalizedCategory);
            }
            String categoryFilter = normalizedCategory;
            List<JourneyResponse> result = journeys.values().stream()
                    .filter(journey -> "active".equals(journey.status()))
                    .filter(journey -> "public".equals(journey.visibility()))
                    .filter(journey -> categoryFilter.isEmpty() || journey.category().equals(categoryFilter))
                    .map(journey -> toJourneyResponse(journey, origin))
                    .filter(journey -> journey.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(JourneyResponse::distanceMeters)
                            .thenComparing(JourneyResponse::title))
                    .toList();
            return new JourneyListResponse(normalizedViewerId, radius, result.size(), result);
        });
    }

    public Uni<JourneyResponse> get(String journeyId, Double lat, Double lng) {
        return Uni.createFrom().item(() -> {
            JourneyRecord journey = requireJourney(journeyId);
            GeoPoint origin = journey.startPosition();
            if (lat != null || lng != null) {
                if (lat == null || lng == null) {
                    throw new BadRequestException("lat and lng query parameters must be provided together");
                }
                origin = origin(lat, lng);
            }
            return toJourneyResponse(journey, origin);
        });
    }

    public Uni<JourneyProgressResponse> start(String journeyId, JourneyStartRequest request) {
        return Uni.createFrom().item(() -> {
            JourneyRecord journey = requireJourney(journeyId);
            if (!"active".equals(journey.status())) {
                throw conflict("Journey is not active");
            }
            if (!"public".equals(journey.visibility())) {
                throw new ForbiddenException("Journey is not public");
            }
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String userId = requireText(request.userId(), "userId");
            Instant now = Instant.now();
            SessionRecord session = new SessionRecord(
                    "journey_session_" + UUID.randomUUID(),
                    journey.journeyId(),
                    userId,
                    "active",
                    new LinkedHashMap<>(),
                    now,
                    now,
                    null);
            sessions.put(session.sessionId(), session);
            return toProgress(session);
        });
    }

    public Uni<JourneyProgressResponse> completeCheckpoint(
            String sessionId,
            String checkpointId,
            CheckpointCompleteRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            SessionRecord session = requireSession(sessionId);
            if (!"active".equals(session.status())) {
                throw conflict("Journey session is " + session.status());
            }
            String userId = requireText(request.userId(), "userId");
            if (!session.userId().equals(userId)) {
                throw new ForbiddenException("Journey session owner mismatch");
            }
            JourneyRecord journey = requireJourney(session.journeyId());
            JourneyCheckpoint checkpoint = requireCheckpoint(journey, checkpointId);
            if (request.position() == null) {
                throw new BadRequestException("position is required");
            }
            validateLatLng(request.position().latitude(), request.position().longitude());
            ensurePriorCheckpointsComplete(journey, checkpoint, session);
            double distance = distanceMeters(request.position().latitude(), request.position().longitude(),
                    checkpoint.position().latitude(), checkpoint.position().longitude());
            if (distance > checkpoint.radiusMeters()) {
                throw new ForbiddenException("User is outside checkpoint radius");
            }
            Instant now = Instant.now();
            Map<String, Instant> completed = new LinkedHashMap<>(session.completedCheckpoints());
            completed.putIfAbsent(checkpoint.checkpointId(), now);
            boolean journeyComplete = journey.checkpoints().stream()
                    .filter(JourneyCheckpoint::required)
                    .allMatch(item -> completed.containsKey(item.checkpointId()));
            SessionRecord updated = session.withProgress(
                    completed,
                    journeyComplete ? "completed" : "active",
                    now,
                    journeyComplete ? now : null);
            sessions.put(updated.sessionId(), updated);
            if (journeyComplete) {
                awardBadge(updated.userId(), journey, now);
            }
            return toProgress(updated);
        });
    }

    public Uni<JourneyProgressResponse> abandon(String sessionId, String userId) {
        return Uni.createFrom().item(() -> {
            SessionRecord session = requireSession(sessionId);
            String normalizedUserId = requireText(userId, "userId");
            if (!session.userId().equals(normalizedUserId)) {
                throw new ForbiddenException("Journey session owner mismatch");
            }
            if (!"active".equals(session.status())) {
                throw conflict("Journey session is " + session.status());
            }
            SessionRecord updated = session.withStatus("abandoned", Instant.now());
            sessions.put(updated.sessionId(), updated);
            return toProgress(updated);
        });
    }

    public Uni<UserJourneysResponse> userJourneys(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<JourneyProgressResponse> result = sessions.values().stream()
                    .filter(session -> session.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(SessionRecord::startedAt).reversed())
                    .map(this::toProgress)
                    .toList();
            return new UserJourneysResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<UserBadgesResponse> userBadges(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<BadgeResponse> result = badges.values().stream()
                    .filter(badge -> badge.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(BadgeRecord::awardedAt).reversed())
                    .map(this::toBadgeResponse)
                    .toList();
            return new UserBadgesResponse(normalizedUserId, result.size(), result);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        add(new JourneyRecord(
                "journey_seed_anchor_loop",
                "Anchor Loop",
                "Follow courtyard and rooftop AR clues, then finish at the campus memory walk.",
                "trail",
                "public",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                190.0,
                18,
                List.of("trail", "ar", "campus"),
                List.of(
                        new JourneyCheckpoint(
                                "checkpoint_courtyard",
                                1,
                                "Courtyard Light",
                                "Stand near the courtyard memory and align with the first marker.",
                                "place",
                                "place_bandung_campus",
                                new GeoPoint(-6.890620, 107.610790, 742.0),
                                45.0,
                                true),
                        new JourneyCheckpoint(
                                "checkpoint_rooftop",
                                2,
                                "Rooftop Compass",
                                "Find the skyline marker beside the virtual wall.",
                                "memory",
                                "memory_seed_rooftop",
                                new GeoPoint(-6.890580, 107.610970, 746.4),
                                45.0,
                                true),
                        new JourneyCheckpoint(
                                "checkpoint_event_start",
                                3,
                                "Memory Walk Start",
                                "Return to the walk start and check the event anchor.",
                                "event",
                                "event_seed_campus_walk",
                                new GeoPoint(-6.890620, 107.610790, 742.0),
                                60.0,
                                true)),
                "badge_anchor_loop",
                "Anchor Loop Finisher",
                "active",
                now.minusSeconds(1_200),
                now.minusSeconds(1_100)));
        add(new JourneyRecord(
                "journey_seed_photo_scout",
                "Photo Scout",
                "Capture a compact set of public photo viewpoints around campus.",
                "photo",
                "public",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                140.0,
                12,
                List.of("photo", "compass", "rooftop"),
                List.of(
                        new JourneyCheckpoint(
                                "checkpoint_photo_rooftop",
                                1,
                                "Skyline Proof",
                                "Visit the rooftop marker and take a direction-aware capture.",
                                "memory",
                                "memory_seed_rooftop",
                                new GeoPoint(-6.890580, 107.610970, 746.4),
                                45.0,
                                true),
                        new JourneyCheckpoint(
                                "checkpoint_photo_courtyard",
                                2,
                                "Courtyard Return",
                                "Return to the courtyard and compare altitude.",
                                "memory",
                                "memory_seed_courtyard",
                                new GeoPoint(-6.890620, 107.610790, 742.0),
                                45.0,
                                true)),
                "badge_photo_scout",
                "Photo Scout",
                "active",
                now.minusSeconds(1_000),
                now.minusSeconds(900)));
        add(new JourneyRecord(
                "journey_seed_private_guardian",
                "Guardian Safety Walk",
                "Private guardian route for teen safety checks.",
                "safety",
                "private",
                new GeoPoint(-6.890760, 107.610830, 742.1),
                90.0,
                10,
                List.of("guardian", "safety"),
                List.of(),
                "badge_guardian_walk",
                "Guardian Walk",
                "active",
                now.minusSeconds(800),
                now.minusSeconds(700)));
        add(new JourneyRecord(
                "journey_seed_far_view",
                "Far View Loop",
                "A route beyond the immediate campus radius.",
                "explore",
                "public",
                new GeoPoint(-6.893100, 107.613300, 739.2),
                700.0,
                35,
                List.of("viewpoint", "far"),
                List.of(),
                "badge_far_view",
                "Far View",
                "active",
                now.minusSeconds(600),
                now.minusSeconds(500)));
    }

    private void add(JourneyRecord journey) {
        journeys.put(journey.journeyId(), journey);
    }

    private JourneyRecord requireJourney(String journeyId) {
        String normalizedJourneyId = requireText(journeyId, "journeyId");
        JourneyRecord journey = journeys.get(normalizedJourneyId);
        if (journey == null) {
            throw new NotFoundException("Journey not found: " + normalizedJourneyId);
        }
        return journey;
    }

    private SessionRecord requireSession(String sessionId) {
        String normalizedSessionId = requireText(sessionId, "sessionId");
        SessionRecord session = sessions.get(normalizedSessionId);
        if (session == null) {
            throw new NotFoundException("Journey session not found: " + normalizedSessionId);
        }
        return session;
    }

    private JourneyCheckpoint requireCheckpoint(JourneyRecord journey, String checkpointId) {
        String normalizedCheckpointId = requireText(checkpointId, "checkpointId");
        return journey.checkpoints().stream()
                .filter(checkpoint -> checkpoint.checkpointId().equals(normalizedCheckpointId))
                .findFirst()
                .orElseThrow(() -> new NotFoundException("Checkpoint not found: " + normalizedCheckpointId));
    }

    private void ensurePriorCheckpointsComplete(
            JourneyRecord journey,
            JourneyCheckpoint checkpoint,
            SessionRecord session) {
        for (JourneyCheckpoint item : journey.checkpoints()) {
            if (item.orderIndex() >= checkpoint.orderIndex()) {
                return;
            }
            if (item.required() && !session.completedCheckpoints().containsKey(item.checkpointId())) {
                throw conflict("Checkpoint " + item.checkpointId() + " must be completed first");
            }
        }
    }

    private JourneyResponse toJourneyResponse(JourneyRecord journey, GeoPoint origin) {
        double distance = distanceMeters(origin.latitude(), origin.longitude(),
                journey.startPosition().latitude(), journey.startPosition().longitude());
        double bearing = bearingDegrees(origin.latitude(), origin.longitude(),
                journey.startPosition().latitude(), journey.startPosition().longitude());
        return new JourneyResponse(
                journey.journeyId(),
                journey.title(),
                journey.description(),
                journey.category(),
                journey.visibility(),
                journey.startPosition(),
                journey.estimatedDistanceMeters(),
                journey.estimatedMinutes(),
                journey.tags(),
                journey.checkpoints(),
                journey.rewardBadgeId(),
                journey.rewardBadgeTitle(),
                journey.status(),
                round2(distance),
                round2(bearing),
                journey.createdAt(),
                journey.updatedAt());
    }

    private JourneyProgressResponse toProgress(SessionRecord session) {
        JourneyRecord journey = requireJourney(session.journeyId());
        List<CheckpointProgress> progress = journey.checkpoints().stream()
                .map(checkpoint -> new CheckpointProgress(
                        checkpoint.checkpointId(),
                        checkpoint.orderIndex(),
                        checkpoint.title(),
                        session.completedCheckpoints().containsKey(checkpoint.checkpointId()),
                        session.completedCheckpoints().get(checkpoint.checkpointId())))
                .toList();
        return new JourneyProgressResponse(
                session.sessionId(),
                session.journeyId(),
                session.userId(),
                session.status(),
                journey.checkpoints().size(),
                session.completedCheckpoints().size(),
                progress,
                badgeForSession(session),
                session.startedAt(),
                session.updatedAt(),
                session.completedAt());
    }

    private BadgeResponse badgeForSession(SessionRecord session) {
        if (!"completed".equals(session.status())) {
            return null;
        }
        JourneyRecord journey = requireJourney(session.journeyId());
        BadgeRecord badge = badges.get(badgeKey(session.userId(), journey.rewardBadgeId()));
        return badge == null ? null : toBadgeResponse(badge);
    }

    private void awardBadge(String userId, JourneyRecord journey, Instant awardedAt) {
        String key = badgeKey(userId, journey.rewardBadgeId());
        badges.putIfAbsent(key, new BadgeRecord(
                userId,
                journey.rewardBadgeId(),
                journey.rewardBadgeTitle(),
                journey.journeyId(),
                awardedAt));
    }

    private BadgeResponse toBadgeResponse(BadgeRecord badge) {
        return new BadgeResponse(
                badge.userId(),
                badge.badgeId(),
                badge.title(),
                badge.journeyId(),
                badge.awardedAt());
    }

    private GeoPoint origin(double lat, double lng) {
        validateLatLng(lat, lng);
        return new GeoPoint(lat, lng, null);
    }

    private double normalizeRadius(Double radiusMeters) {
        return normalizePositiveDouble(radiusMeters, 1_000.0, MAX_RADIUS_METERS, "radiusMeters");
    }

    private String normalizeCategory(String value) {
        return requireChoice(value, CATEGORIES, "category");
    }

    private String normalizeVisibility(String value) {
        return requireChoice(value, VISIBILITIES, "visibility");
    }

    private String normalizeTargetType(String value) {
        return requireChoice(value, JOURNEY_TARGET_TYPES, "targetType");
    }

    private String badgeKey(String userId, String badgeId) {
        return userId + "|" + badgeId;
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }

    private record JourneyRecord(
            String journeyId,
            String title,
            String description,
            String category,
            String visibility,
            GeoPoint startPosition,
            double estimatedDistanceMeters,
            int estimatedMinutes,
            List<String> tags,
            List<JourneyCheckpoint> checkpoints,
            String rewardBadgeId,
            String rewardBadgeTitle,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }

    private record SessionRecord(
            String sessionId,
            String journeyId,
            String userId,
            String status,
            Map<String, Instant> completedCheckpoints,
            Instant startedAt,
            Instant updatedAt,
            Instant completedAt) {
        private SessionRecord withProgress(
                Map<String, Instant> completedCheckpoints,
                String status,
                Instant updatedAt,
                Instant completedAt) {
            return new SessionRecord(
                    sessionId,
                    journeyId,
                    userId,
                    status,
                    completedCheckpoints,
                    startedAt,
                    updatedAt,
                    completedAt == null ? this.completedAt : completedAt);
        }

        private SessionRecord withStatus(String status, Instant updatedAt) {
            return new SessionRecord(
                    sessionId,
                    journeyId,
                    userId,
                    status,
                    completedCheckpoints,
                    startedAt,
                    updatedAt,
                    completedAt);
        }
    }

    private record BadgeRecord(
            String userId,
            String badgeId,
            String title,
            String journeyId,
            Instant awardedAt) {
    }
}
