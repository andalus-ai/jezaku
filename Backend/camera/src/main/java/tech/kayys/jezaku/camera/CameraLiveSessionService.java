package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Multi;
import io.smallrye.mutiny.Uni;
import io.smallrye.mutiny.subscription.MultiEmitter;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionCreateRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEndRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionHeartbeatRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionPauseRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResumeRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionUpdateRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;

import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.orientationDegrees;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedLong;
import static tech.kayys.jezaku.validation.RequestParams.normalizeOptionalBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

@ApplicationScoped
public class CameraLiveSessionService {
    private static final double DEFAULT_SHARE_RADIUS_METERS = 100.0;
    private static final double MAX_SHARE_RADIUS_METERS = 1_000.0;
    private static final long DEFAULT_TTL_SECONDS = 120;
    private static final long MIN_TTL_SECONDS = 15;
    private static final long MAX_TTL_SECONDS = 900;
    private static final int MAX_EVENTS_PER_SESSION = 100;
    private static final int MAX_VIEWER_ID_LENGTH = 80;
    private static final int MAX_STATUS_MESSAGE_LENGTH = 120;
    private static final Set<String> VISIBILITIES = Set.of("public", "friends", "private");
    private static final Set<String> STATUSES = Set.of("live", "paused", "ended");

    private final ConcurrentMap<String, CameraSessionRecord> sessions = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, CopyOnWriteArrayList<CameraSessionEventRecord>> eventsBySession =
            new ConcurrentHashMap<>();
    private final ConcurrentMap<String, CopyOnWriteArrayList<CameraSessionStreamSubscription>> streamSubscribers =
            new ConcurrentHashMap<>();
    private final AtomicLong eventSequence = new AtomicLong();

    public Uni<CameraSessionResponse> create(CameraSessionCreateRequest request) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(createAt(now, request), now);
        });
    }

    public Uni<CameraSessionResponse> get(String sessionId) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(requireSession(sessionId), now);
        });
    }

    public Uni<CameraSessionResponse> update(String sessionId, CameraSessionUpdateRequest request) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(updateAt(sessionId, request, now), now);
        });
    }

    public Uni<CameraSessionResponse> heartbeat(String sessionId, CameraSessionHeartbeatRequest request) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(heartbeatAt(sessionId, request, now), now);
        });
    }

    public Uni<CameraSessionResponse> pause(String sessionId, CameraSessionPauseRequest request) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(pauseAt(sessionId, request, now), now);
        });
    }

    public Uni<CameraSessionResponse> resume(String sessionId, CameraSessionResumeRequest request) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(resumeAt(sessionId, request, now), now);
        });
    }

    public Uni<CameraSessionResponse> end(String sessionId, CameraSessionEndRequest request) {
        return Uni.createFrom().item(() -> {
            Instant now = Instant.now();
            return toResponse(endAt(sessionId, request, now), now);
        });
    }

    public Uni<CameraSessionEventListResponse> events(String sessionId, Integer limit, Long afterSequence) {
        return Uni.createFrom().item(() -> eventsAt(sessionId, limit, afterSequence, Instant.now()));
    }

    public Multi<CameraSessionEventResponse> streamEvents(String sessionId, Integer maxEvents, Long afterSequence) {
        CameraSessionRecord session = requireSession(sessionId);
        int eventLimit = normalizeBoundedInt(
                maxEvents,
                CameraSyncContract.DEFAULT_STREAM_EVENT_LIMIT,
                CameraSyncContract.MIN_STREAM_EVENT_LIMIT,
                CameraSyncContract.MAX_STREAM_EVENT_LIMIT,
                "maxEvents");
        long cursor = normalizeBoundedLong(
                afterSequence,
                CameraSyncContract.DEFAULT_CURSOR,
                CameraSyncContract.MIN_CURSOR,
                Long.MAX_VALUE,
                "afterSequence");
        return Multi.createFrom().emitter(emitter -> {
            CameraSessionStreamSubscription subscription = new CameraSessionStreamSubscription(emitter, eventLimit);
            CopyOnWriteArrayList<CameraSessionStreamSubscription> subscribers = streamSubscribers.computeIfAbsent(
                    session.sessionId(),
                    ignored -> new CopyOnWriteArrayList<>());
            subscribers.add(subscription);
            emitter.onTermination(() -> subscribers.remove(subscription));
            eventsAt(session.sessionId(), eventLimit, cursor, Instant.now()).events()
                    .forEach(subscription::emit);
            if (subscription.complete()) {
                subscribers.remove(subscription);
            }
        });
    }

    CameraSessionRecord activeSession(String sessionId, Instant now) {
        CameraSessionRecord session = requireSession(sessionId);
        if (!session.activeAt(now)) {
            throw new BadRequestException("camera session is not active");
        }
        return session;
    }

    CameraSessionResponse response(CameraSessionRecord record, Instant now) {
        return toResponse(record, now);
    }

    CameraSessionRecord createAt(Instant now, CameraSessionCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }
        if (request.lat() == null || request.lng() == null) {
            throw new BadRequestException("lat and lng are required");
        }

        String viewerId = requireTextMaxLength(request.viewerId(), "viewerId", MAX_VIEWER_ID_LENGTH);
        GeoPoint position = point(request.lat(), request.lng(), request.altitudeMeters());
        Double heading = normalizeDegrees(request.headingDegrees(), "headingDegrees");
        Double compass = normalizeDegrees(request.compassDegrees(), "compassDegrees");
        Double speed = speed(request.speedMetersPerSecond());
        double radius = radius(request.radiusMeters());
        double shareRadius = shareRadius(request.shareRadiusMeters());
        String visibility = visibility(request.visibility(), "public");
        String statusMessage = statusMessage(request.statusMessage(), "");
        Instant expiresAt = now.plusSeconds(ttlSeconds(request.ttlSeconds(), DEFAULT_TTL_SECONDS));

        CameraSessionRecord record = new CameraSessionRecord(
                UUID.randomUUID().toString(),
                viewerId,
                "live",
                visibility,
                position,
                heading,
                compass,
                speed,
                radius,
                shareRadius,
                statusMessage,
                now,
                now,
                expiresAt);
        sessions.put(record.sessionId(), record);
        recordEvent("session.created", record, now);
        return record;
    }

    CameraSessionRecord updateAt(String sessionId, CameraSessionUpdateRequest request, Instant now) {
        if (request == null) {
            throw new BadRequestException("request body is required");
        }
        CameraSessionRecord existing = requireSession(sessionId);
        GeoPoint position = updatedPoint(existing.position(), request);
        Double heading = request.headingDegrees() == null
                ? existing.headingDegrees()
                : normalizeDegrees(request.headingDegrees(), "headingDegrees");
        Double compass = request.compassDegrees() == null
                ? existing.compassDegrees()
                : normalizeDegrees(request.compassDegrees(), "compassDegrees");
        Double speed = request.speedMetersPerSecond() == null
                ? existing.speedMetersPerSecond()
                : speed(request.speedMetersPerSecond());
        double radius = request.radiusMeters() == null ? existing.radiusMeters() : radius(request.radiusMeters());
        double shareRadius = request.shareRadiusMeters() == null
                ? existing.shareRadiusMeters()
                : shareRadius(request.shareRadiusMeters());
        String visibility = request.visibility() == null
                ? existing.visibility()
                : visibility(request.visibility(), existing.visibility());
        String status = status(request.status(), existing.status());
        String statusMessage = request.statusMessage() == null
                ? existing.statusMessage()
                : statusMessage(request.statusMessage(), existing.statusMessage());
        Instant expiresAt = "ended".equals(status)
                ? now
                : now.plusSeconds(ttlSeconds(request.ttlSeconds(), DEFAULT_TTL_SECONDS));

        CameraSessionRecord updated = new CameraSessionRecord(
                existing.sessionId(),
                existing.viewerId(),
                status,
                visibility,
                position,
                heading,
                compass,
                speed,
                radius,
                shareRadius,
                statusMessage,
                existing.createdAt(),
                now,
                expiresAt);
        sessions.put(updated.sessionId(), updated);
        recordUpdateEvents(existing, updated, now);
        return updated;
    }

    CameraSessionRecord heartbeatAt(String sessionId, CameraSessionHeartbeatRequest request, Instant now) {
        CameraSessionRecord existing = activeSession(sessionId, now);
        long ttl = ttlSeconds(request == null ? null : request.ttlSeconds(), DEFAULT_TTL_SECONDS);
        CameraSessionRecord updated = new CameraSessionRecord(
                existing.sessionId(),
                existing.viewerId(),
                existing.status(),
                existing.visibility(),
                existing.position(),
                existing.headingDegrees(),
                existing.compassDegrees(),
                existing.speedMetersPerSecond(),
                existing.radiusMeters(),
                existing.shareRadiusMeters(),
                existing.statusMessage(),
                existing.createdAt(),
                now,
                now.plusSeconds(ttl));
        sessions.put(updated.sessionId(), updated);
        recordEvent("session.heartbeat", updated, now);
        return updated;
    }

    CameraSessionRecord pauseAt(String sessionId, CameraSessionPauseRequest request, Instant now) {
        CameraSessionRecord existing = requireSession(sessionId);
        ensureNotEnded(existing);
        if ("paused".equals(existing.status())) {
            return existing;
        }
        long ttl = ttlSeconds(request == null ? null : request.ttlSeconds(), DEFAULT_TTL_SECONDS);
        String statusMessage = request == null || request.statusMessage() == null
                ? existing.statusMessage()
                : statusMessage(request.statusMessage(), existing.statusMessage());
        CameraSessionRecord paused = statusTransition(existing, "paused", statusMessage, now, now.plusSeconds(ttl));
        sessions.put(paused.sessionId(), paused);
        recordEvent("status.changed", paused, now);
        recordEvent("session.paused", paused, now);
        return paused;
    }

    CameraSessionRecord resumeAt(String sessionId, CameraSessionResumeRequest request, Instant now) {
        CameraSessionRecord existing = requireSession(sessionId);
        ensureNotEnded(existing);
        if ("live".equals(existing.status())) {
            return existing;
        }
        long ttl = ttlSeconds(request == null ? null : request.ttlSeconds(), DEFAULT_TTL_SECONDS);
        String statusMessage = request == null || request.statusMessage() == null
                ? existing.statusMessage()
                : statusMessage(request.statusMessage(), existing.statusMessage());
        CameraSessionRecord live = statusTransition(existing, "live", statusMessage, now, now.plusSeconds(ttl));
        sessions.put(live.sessionId(), live);
        recordEvent("status.changed", live, now);
        recordEvent("session.resumed", live, now);
        return live;
    }

    CameraSessionRecord endAt(String sessionId, CameraSessionEndRequest request, Instant now) {
        CameraSessionRecord existing = requireSession(sessionId);
        if ("ended".equals(existing.status())) {
            return existing;
        }
        String statusMessage = request == null || request.statusMessage() == null
                ? existing.statusMessage()
                : statusMessage(request.statusMessage(), existing.statusMessage());
        CameraSessionRecord ended = new CameraSessionRecord(
                existing.sessionId(),
                existing.viewerId(),
                "ended",
                existing.visibility(),
                existing.position(),
                existing.headingDegrees(),
                existing.compassDegrees(),
                existing.speedMetersPerSecond(),
                existing.radiusMeters(),
                existing.shareRadiusMeters(),
                statusMessage,
                existing.createdAt(),
                now,
                now);
        sessions.put(ended.sessionId(), ended);
        recordEvent("status.changed", ended, now);
        recordEvent("session.ended", ended, now);
        return ended;
    }

    CameraSessionEventListResponse eventsAt(String sessionId, Integer limit, Long afterSequence, Instant now) {
        CameraSessionRecord session = requireSession(sessionId);
        int eventLimit = normalizeBoundedInt(
                limit,
                CameraSyncContract.DEFAULT_EVENT_LIMIT,
                CameraSyncContract.MIN_EVENT_LIMIT,
                CameraSyncContract.MAX_EVENT_LIMIT,
                "limit");
        long cursor = normalizeBoundedLong(
                afterSequence,
                CameraSyncContract.DEFAULT_CURSOR,
                CameraSyncContract.MIN_CURSOR,
                Long.MAX_VALUE,
                "afterSequence");
        List<CameraSessionEventRecord> events = new ArrayList<>(
                eventsBySession.getOrDefault(session.sessionId(), new CopyOnWriteArrayList<>()));
        List<CameraSessionEventRecord> matching = events.stream()
                .filter(event -> event.sequence() > cursor)
                .sorted(Comparator.comparingLong(CameraSessionEventRecord::sequence))
                .toList();
        int fromIndex = cursor == 0 ? Math.max(0, matching.size() - eventLimit) : 0;
        int toIndex = Math.min(matching.size(), fromIndex + eventLimit);
        List<CameraSessionEventResponse> responses = matching.subList(fromIndex, toIndex).stream()
                .map(this::toEventResponse)
                .toList();
        boolean hasMore = cursor == 0 ? fromIndex > 0 : toIndex < matching.size();
        long lastSequence = responses.isEmpty() ? cursor : responses.getLast().sequence();
        return new CameraSessionEventListResponse(
                session.sessionId(),
                responses.size(),
                lastSequence,
                hasMore,
                responses,
                now);
    }

    List<CameraSessionRecord> activeSessions(Instant now) {
        return sessions.values().stream()
                .filter(session -> session.activeAt(now))
                .sorted(Comparator.comparing(CameraSessionRecord::updatedAt).reversed()
                        .thenComparing(CameraSessionRecord::sessionId))
                .toList();
    }

    private void recordUpdateEvents(CameraSessionRecord previous, CameraSessionRecord updated, Instant now) {
        if (telemetryChanged(previous, updated)) {
            recordEvent("telemetry.updated", updated, now);
        }
        if (!previous.visibility().equals(updated.visibility())) {
            recordEvent("visibility.changed", updated, now);
        }
        if (!previous.status().equals(updated.status())) {
            recordEvent("status.changed", updated, now);
            if ("ended".equals(updated.status())) {
                recordEvent("session.ended", updated, now);
            }
        }
    }

    private void ensureNotEnded(CameraSessionRecord session) {
        if ("ended".equals(session.status())) {
            throw new BadRequestException("camera session is ended");
        }
    }

    private CameraSessionRecord statusTransition(
            CameraSessionRecord session,
            String status,
            String statusMessage,
            Instant updatedAt,
            Instant expiresAt) {
        return new CameraSessionRecord(
                session.sessionId(),
                session.viewerId(),
                status,
                session.visibility(),
                session.position(),
                session.headingDegrees(),
                session.compassDegrees(),
                session.speedMetersPerSecond(),
                session.radiusMeters(),
                session.shareRadiusMeters(),
                statusMessage,
                session.createdAt(),
                updatedAt,
                expiresAt);
    }

    private boolean telemetryChanged(CameraSessionRecord previous, CameraSessionRecord updated) {
        return !previous.position().equals(updated.position())
                || !Objects.equals(previous.headingDegrees(), updated.headingDegrees())
                || !Objects.equals(previous.compassDegrees(), updated.compassDegrees())
                || !Objects.equals(previous.speedMetersPerSecond(), updated.speedMetersPerSecond())
                || Double.compare(previous.radiusMeters(), updated.radiusMeters()) != 0
                || Double.compare(previous.shareRadiusMeters(), updated.shareRadiusMeters()) != 0
                || !previous.statusMessage().equals(updated.statusMessage());
    }

    private void recordEvent(String type, CameraSessionRecord session, Instant now) {
        CopyOnWriteArrayList<CameraSessionEventRecord> events = eventsBySession.computeIfAbsent(
                session.sessionId(),
                ignored -> new CopyOnWriteArrayList<>());
        CameraSessionEventRecord event = new CameraSessionEventRecord(
                UUID.randomUUID().toString(),
                eventSequence.incrementAndGet(),
                session.sessionId(),
                session.viewerId(),
                type,
                session.status(),
                session.visibility(),
                session.position(),
                session.headingDegrees(),
                session.compassDegrees(),
                session.speedMetersPerSecond(),
                session.radiusMeters(),
                session.shareRadiusMeters(),
                session.statusMessage(),
                now);
        events.add(event);
        trimEvents(events);
        broadcastEvent(event);
    }

    private void trimEvents(CopyOnWriteArrayList<CameraSessionEventRecord> events) {
        while (events.size() > MAX_EVENTS_PER_SESSION) {
            events.remove(0);
        }
    }

    private void broadcastEvent(CameraSessionEventRecord event) {
        List<CameraSessionStreamSubscription> subscribers = streamSubscribers.get(event.sessionId());
        if (subscribers == null || subscribers.isEmpty()) {
            return;
        }
        CameraSessionEventResponse response = toEventResponse(event);
        for (CameraSessionStreamSubscription subscriber : subscribers) {
            if (subscriber.complete() || !subscriber.emit(response)) {
                subscribers.remove(subscriber);
            }
        }
    }

    private CameraSessionRecord requireSession(String sessionId) {
        String normalizedSessionId = requireTextMaxLength(sessionId, "sessionId", 120);
        CameraSessionRecord record = sessions.get(normalizedSessionId);
        if (record == null) {
            throw new NotFoundException("Camera session not found");
        }
        return record;
    }

    private CameraSessionResponse toResponse(CameraSessionRecord record, Instant now) {
        return new CameraSessionResponse(
                record.sessionId(),
                record.viewerId(),
                record.status(),
                record.activeAt(now),
                CameraSessionGuidancePolicies.from(record, now),
                record.visibility(),
                telemetry(record),
                record.shareRadiusMeters(),
                record.statusMessage(),
                record.createdAt(),
                record.updatedAt(),
                record.expiresAt());
    }

    private CameraSessionEventResponse toEventResponse(CameraSessionEventRecord event) {
        return new CameraSessionEventResponse(
                event.eventId(),
                event.sequence(),
                event.sessionId(),
                event.viewerId(),
                event.type(),
                event.status(),
                event.visibility(),
                event.position(),
                event.headingDegrees(),
                event.compassDegrees(),
                event.speedMetersPerSecond() == null ? null : round2(event.speedMetersPerSecond()),
                event.radiusMeters(),
                event.shareRadiusMeters(),
                event.statusMessage(),
                event.eventAt());
    }

    private CameraTelemetry telemetry(CameraSessionRecord record) {
        Double speed = record.speedMetersPerSecond() == null ? null : round2(record.speedMetersPerSecond());
        return new CameraTelemetry(
                record.viewerId(),
                record.position(),
                record.headingDegrees(),
                record.compassDegrees(),
                orientationDegrees(record.headingDegrees(), record.compassDegrees()),
                speed,
                CameraTelemetryQualityPolicy.evaluate(null, null, null, null, speed, null),
                record.radiusMeters(),
                record.updatedAt());
    }

    private GeoPoint updatedPoint(GeoPoint current, CameraSessionUpdateRequest request) {
        boolean hasLat = request.lat() != null;
        boolean hasLng = request.lng() != null;
        if (hasLat != hasLng) {
            throw new BadRequestException("lat and lng must be provided together");
        }
        if (!hasLat && request.altitudeMeters() == null) {
            return current;
        }
        double lat = hasLat ? request.lat() : current.latitude();
        double lng = hasLng ? request.lng() : current.longitude();
        Double altitude = request.altitudeMeters() == null ? current.altitudeMeters() : finite(request.altitudeMeters(),
                "altitudeMeters");
        return point(lat, lng, altitude);
    }

    private GeoPoint point(double lat, double lng, Double altitudeMeters) {
        validateLatLng(lat, lng);
        return new GeoPoint(lat, lng, altitudeMeters == null ? null : finite(altitudeMeters, "altitudeMeters"));
    }

    private Double speed(Double value) {
        return normalizeOptionalBoundedDouble(value, 0.0, 100.0, "speedMetersPerSecond");
    }

    private double radius(Double value) {
        return normalizePositiveDouble(
                value,
                CameraSyncContract.DEFAULT_RADIUS_METERS,
                CameraSyncContract.MAX_RADIUS_METERS,
                "radiusMeters");
    }

    private double shareRadius(Double value) {
        return normalizePositiveDouble(
                value,
                DEFAULT_SHARE_RADIUS_METERS,
                MAX_SHARE_RADIUS_METERS,
                "shareRadiusMeters");
    }

    private long ttlSeconds(Long value, long defaultValue) {
        return normalizeBoundedLong(value, defaultValue, MIN_TTL_SECONDS, MAX_TTL_SECONDS, "ttlSeconds");
    }

    private String visibility(String value, String defaultValue) {
        return optionalChoice(
                value,
                defaultValue,
                VISIBILITIES,
                "visibility",
                "visibility must be public, friends, or private");
    }

    private String status(String value, String defaultValue) {
        return optionalChoice(value, defaultValue, STATUSES, "status", "status must be live, paused, or ended");
    }

    private String statusMessage(String value, String defaultValue) {
        return optionalTextMaxLength(value, defaultValue, "statusMessage", MAX_STATUS_MESSAGE_LENGTH);
    }

    private Double finite(Double value, String fieldName) {
        if (value == null) {
            return null;
        }
        if (!Double.isFinite(value)) {
            throw new BadRequestException(fieldName + " must be finite");
        }
        return round2(value);
    }

    private static final class CameraSessionStreamSubscription {
        private final MultiEmitter<? super CameraSessionEventResponse> emitter;
        private final int maxEvents;
        private int emitted;
        private boolean complete;

        private CameraSessionStreamSubscription(
                MultiEmitter<? super CameraSessionEventResponse> emitter,
                int maxEvents) {
            this.emitter = emitter;
            this.maxEvents = maxEvents;
        }

        private synchronized boolean emit(CameraSessionEventResponse event) {
            if (complete) {
                return false;
            }
            try {
                emitter.emit(event);
                emitted++;
                if (emitted >= maxEvents) {
                    complete = true;
                    emitter.complete();
                    return false;
                }
                return true;
            } catch (RuntimeException failure) {
                complete = true;
                return false;
            }
        }

        private synchronized boolean complete() {
            return complete;
        }
    }
}
