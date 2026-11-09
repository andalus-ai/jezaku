package tech.kayys.jezaku.events;

import io.smallrye.mutiny.Uni;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.events.EventDtos.CheckInRequest;
import tech.kayys.jezaku.events.EventDtos.CheckInResponse;
import tech.kayys.jezaku.events.EventDtos.EventActivityHistoryResponse;
import tech.kayys.jezaku.events.EventDtos.EventActivityResponse;
import tech.kayys.jezaku.events.EventDtos.EventCreateRequest;
import tech.kayys.jezaku.events.EventDtos.EventFeedResponse;
import tech.kayys.jezaku.events.EventDtos.EventResponse;
import tech.kayys.jezaku.events.EventDtos.GeoPoint;
import tech.kayys.jezaku.events.EventDtos.InviteRequest;
import tech.kayys.jezaku.events.EventDtos.InviteResponse;
import tech.kayys.jezaku.events.EventDtos.RsvpRequest;
import tech.kayys.jezaku.events.EventDtos.RsvpResponse;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static tech.kayys.jezaku.taxonomy.JezakuChoices.VISIBILITIES;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.EVENT_RSVP_STATUSES;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class EventService {
    private static final Set<String> CATEGORIES = Set.of("trail", "meetup", "challenge", "workshop", "safety");
    private static final double DEFAULT_CHECK_IN_RADIUS_METERS = 50.0;
    private static final double MAX_SEARCH_RADIUS_METERS = 5_000.0;

    @Inject
    EventRepository repository;

    @PostConstruct
    void initialize() {
        seed();
    }

    public Uni<EventResponse> create(EventCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateCreate(request);
            Instant now = Instant.now();
            EventRecord event = new EventRecord(
                    "event_" + UUID.randomUUID(),
                    request.organizerId().trim(),
                    request.title().trim(),
                    optionalTrim(request.description(), ""),
                    normalizeCategory(request.category()),
                    normalizeVisibility(request.visibility()),
                    optionalTrim(request.placeId(), null),
                    request.center(),
                    normalizeCheckInRadius(request.checkInRadiusMeters()),
                    request.startsAt(),
                    request.endsAt(),
                    normalizeCapacity(request.capacity()),
                    normalizeStrings(request.tags()),
                    normalizeStrings(request.anchorIds()),
                    "scheduled",
                    now,
                    now);
            repository.saveEvent(event);
            recordActivity(event.id(), event.organizerId(), "created", event.organizerId(), "Event created", now);
            return toResponse(event, event.center());
        });
    }

    public Uni<EventResponse> get(String eventId, Double lat, Double lng) {
        return Uni.createFrom().item(() -> {
            EventRecord event = requireEvent(eventId);
            GeoPoint viewer = lat == null || lng == null ? event.center() : new GeoPoint(lat, lng, null);
            return toResponse(event, viewer);
        });
    }

    public Uni<List<EventResponse>> nearby(double lat, double lng, Double radiusMeters, String category) {
        return Uni.createFrom().item(() -> {
            validateLatLng(lat, lng);
            GeoPoint viewer = new GeoPoint(lat, lng, null);
            double radius = normalizeSearchRadius(radiusMeters);
            String normalizedCategory = optionalTrim(category, null);
            if (normalizedCategory != null) {
                normalizedCategory = normalizeCategory(normalizedCategory);
            }
            String categoryFilter = normalizedCategory;
            return repository.findAllEvents().stream()
                    .filter(event -> "scheduled".equals(event.status()))
                    .filter(event -> "public".equals(event.visibility()))
                    .filter(event -> event.endsAt().isAfter(Instant.now()))
                    .filter(event -> categoryFilter == null || event.category().equals(categoryFilter))
                    .map(event -> toResponse(event, viewer))
                    .filter(event -> event.distanceMeters() <= radius)
                    .sorted(Comparator.comparingDouble(EventResponse::distanceMeters)
                            .thenComparing(EventResponse::startsAt))
                    .toList();
        });
    }

    public Uni<EventFeedResponse> userEvents(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<EventResponse> result = repository.findAllEvents().stream()
                    .filter(event -> event.organizerId().equals(normalizedUserId)
                            || repository.findRsvp(event.id(), normalizedUserId) != null
                            || repository.findAllInvites().stream().anyMatch(invite -> invite.eventId().equals(event.id())
                            && invite.inviteeUserId().equals(normalizedUserId)))
                    .sorted(Comparator.comparing(EventRecord::startsAt))
                    .map(event -> toResponse(event, event.center()))
                    .toList();
            return new EventFeedResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<RsvpResponse> rsvp(String eventId, RsvpRequest request) {
        return Uni.createFrom().item(() -> {
            EventRecord event = requireEvent(eventId);
            if (!"scheduled".equals(event.status())) {
                throw conflict("Cannot RSVP to a " + event.status() + " event");
            }
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String userId = requireText(request.userId(), "userId");
            String status = normalizeRsvpStatus(request.status());
            RsvpRecord existing = repository.findRsvp(event.id(), userId);
            boolean alreadyGoing = existing != null && "going".equals(existing.status());
            if ("going".equals(status) && !alreadyGoing && goingCount(event.id()) >= event.capacity()) {
                throw conflict("Event is full");
            }
            Instant now = Instant.now();
            RsvpRecord saved = new RsvpRecord(event.id(), userId, status, now);
            repository.saveRsvp(saved);
            recordActivity(event.id(), userId, "rsvp", userId, status, now);
            return toResponse(saved);
        });
    }

    public Uni<EventActivityHistoryResponse> activity(String eventId, String viewerUserId) {
        return Uni.createFrom().item(() -> {
            EventRecord event = requireEvent(eventId);
            String viewer = requireText(viewerUserId, "viewerUserId");
            if (!event.organizerId().equals(viewer)) {
                throw new ForbiddenException("Only the organizer can view event activity");
            }
            List<EventActivityResponse> activity = repository.findActivityByEventId(event.id()).stream()
                    .sorted(Comparator.comparing(EventActivityEvent::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new EventActivityHistoryResponse(event.id(), activity.size(), activity);
        });
    }

    public Uni<CheckInResponse> checkIn(String eventId, CheckInRequest request) {
        return Uni.createFrom().item(() -> {
            EventRecord event = requireEvent(eventId);
            if (!"scheduled".equals(event.status())) {
                throw conflict("Cannot check in to a " + event.status() + " event");
            }
            if (request == null || request.position() == null) {
                throw new BadRequestException("position is required");
            }
            String userId = requireText(request.userId(), "userId");
            validateLatLng(request.position().latitude(), request.position().longitude());
            double distance = distanceMeters(
                    event.center().latitude(),
                    event.center().longitude(),
                    request.position().latitude(),
                    request.position().longitude());
            if (distance > event.checkInRadiusMeters()) {
                throw new ForbiddenException("User is outside event check-in radius");
            }
            Instant now = Instant.now();
            if (repository.findRsvp(event.id(), userId) == null) {
                repository.saveRsvp(new RsvpRecord(event.id(), userId, "going", now));
            }
            CheckInRecord checkIn = new CheckInRecord(event.id(), userId, round2(distance), now);
            repository.saveCheckIn(checkIn);
            recordActivity(event.id(), userId, "check_in", userId, "distance=" + checkIn.distanceMeters(), now);
            return new CheckInResponse(event.id(), userId, true, checkIn.distanceMeters(), checkIn.checkedInAt());
        });
    }

    public Uni<List<InviteResponse>> invite(String eventId, InviteRequest request) {
        return Uni.createFrom().item(() -> {
            EventRecord event = requireEvent(eventId);
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String inviterId = requireText(request.inviterId(), "inviterId");
            if (!event.organizerId().equals(inviterId)) {
                throw new ForbiddenException("Only the organizer can invite users");
            }
            if (request.inviteeUserIds() == null || request.inviteeUserIds().isEmpty()) {
                throw new BadRequestException("inviteeUserIds is required");
            }
            Instant now = Instant.now();
            List<InviteResponse> created = new ArrayList<>();
            for (String invitee : request.inviteeUserIds()) {
                String inviteeUserId = requireText(invitee, "inviteeUserId");
                InviteRecord existing = repository.findInvite(event.id(), inviteeUserId);
                InviteRecord invite = new InviteRecord(
                        existing == null ? "invite_" + UUID.randomUUID() : existing.id(),
                        event.id(),
                        inviterId,
                        inviteeUserId,
                        optionalTrim(request.message(), ""),
                        "pending",
                        existing == null ? now : existing.createdAt(),
                        now);
                repository.saveInvite(invite);
                recordActivity(event.id(), inviterId, "invite", inviteeUserId, invite.message(), now);
                created.add(toResponse(invite));
            }
            return created;
        });
    }

    public Uni<List<InviteResponse>> invitations(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            return repository.findAllInvites().stream()
                    .filter(invite -> invite.inviteeUserId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(InviteRecord::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
        });
    }

    public Uni<EventResponse> cancel(String eventId, String actorUserId) {
        return Uni.createFrom().item(() -> {
            EventRecord event = requireEvent(eventId);
            String actor = requireText(actorUserId, "actorUserId");
            if (!event.organizerId().equals(actor)) {
                throw new ForbiddenException("Only the organizer can cancel this event");
            }
            EventRecord cancelled = event.withStatus("cancelled", Instant.now());
            repository.saveEvent(cancelled);
            recordActivity(cancelled.id(), actor, "cancelled", "", "Event cancelled", cancelled.updatedAt());
            return toResponse(cancelled, cancelled.center());
        });
    }

    private void seed() {
        Instant now = Instant.now();
        addSeed(new EventRecord(
                "event_seed_campus_walk",
                "user_current",
                "Campus Memory Walk",
                "A short trail through public photo anchors and AR wall clues.",
                "trail",
                "public",
                "place_bandung_campus",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                60.0,
                now.plusSeconds(3_600),
                now.plusSeconds(7_200),
                24,
                List.of("trail", "photo", "campus"),
                List.of("anchor_courtyard", "anchor_rooftop"),
                "scheduled",
                now.minusSeconds(900),
                now.minusSeconds(900)));
        addSeed(new EventRecord(
                "event_seed_rooftop_meet",
                "user_rooftop",
                "Rooftop Compass Meetup",
                "Small meetup for skyline direction captures.",
                "meetup",
                "public",
                "place_rooftop_lane",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                45.0,
                now.plusSeconds(5_400),
                now.plusSeconds(9_000),
                12,
                List.of("compass", "rooftop"),
                List.of("anchor_rooftop"),
                "scheduled",
                now.minusSeconds(700),
                now.minusSeconds(700)));
        addSeed(new EventRecord(
                "event_seed_private_family",
                "guardian_1",
                "Guardian Safety Walk",
                "Private route review for child accounts.",
                "safety",
                "private",
                "place_bandung_campus",
                new GeoPoint(-6.890760, 107.610830, 742.1),
                40.0,
                now.plusSeconds(6_000),
                now.plusSeconds(8_000),
                8,
                List.of("safety", "guardian"),
                List.of(),
                "scheduled",
                now.minusSeconds(500),
                now.minusSeconds(500)));
    }

    private void addSeed(EventRecord event) {
        repository.saveEvent(event);
    }

    private EventRecord requireEvent(String eventId) {
        String id = requireText(eventId, "eventId");
        EventRecord event = repository.findEventById(id);
        if (event == null) {
            throw new NotFoundException("Event not found: " + id);
        }
        return event;
    }

    private EventResponse toResponse(EventRecord event, GeoPoint viewer) {
        return new EventResponse(
                event.id(),
                event.organizerId(),
                event.title(),
                event.description(),
                event.category(),
                event.visibility(),
                event.placeId(),
                event.center(),
                event.checkInRadiusMeters(),
                event.startsAt(),
                event.endsAt(),
                event.capacity(),
                event.tags(),
                event.anchorIds(),
                event.status(),
                goingCount(event.id()),
                interestedCount(event.id()),
                checkedInCount(event.id()),
                invitationCount(event.id()),
                round2(distanceMeters(
                        viewer.latitude(),
                        viewer.longitude(),
                        event.center().latitude(),
                        event.center().longitude())),
                event.createdAt(),
                event.updatedAt());
    }

    private RsvpResponse toResponse(RsvpRecord rsvp) {
        return new RsvpResponse(rsvp.eventId(), rsvp.userId(), rsvp.status(), rsvp.updatedAt());
    }

    private InviteResponse toResponse(InviteRecord invite) {
        return new InviteResponse(invite.id(), invite.eventId(), invite.inviterId(), invite.inviteeUserId(),
                invite.message(), invite.status(), invite.createdAt(), invite.updatedAt());
    }

    private EventActivityResponse toResponse(EventActivityEvent activity) {
        return new EventActivityResponse(
                activity.activityId(),
                activity.eventId(),
                activity.actorUserId(),
                activity.activityType(),
                activity.targetUserId(),
                activity.detail(),
                activity.createdAt());
    }

    private void recordActivity(
            String eventId,
            String actorUserId,
            String activityType,
            String targetUserId,
            String detail,
            Instant createdAt) {
        repository.saveActivity(new EventActivityEvent(
                "event_activity_" + UUID.randomUUID(),
                eventId,
                actorUserId,
                activityType,
                targetUserId,
                detail,
                createdAt));
    }

    private void validateCreate(EventCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.organizerId(), "organizerId");
        requireText(request.title(), "title");
        normalizeCategory(request.category());
        normalizeVisibility(request.visibility());
        if (request.center() == null) {
            throw new BadRequestException("center is required");
        }
        validateLatLng(request.center().latitude(), request.center().longitude());
        if (request.startsAt() == null || request.endsAt() == null) {
            throw new BadRequestException("startsAt and endsAt are required");
        }
        if (!request.endsAt().isAfter(request.startsAt())) {
            throw new BadRequestException("endsAt must be after startsAt");
        }
    }

    private String normalizeCategory(String value) {
        return requireChoice(value, CATEGORIES, "category", "category must be trail, meetup, challenge, workshop, or safety");
    }

    private String normalizeVisibility(String value) {
        return optionalChoice(value, "public", VISIBILITIES, "visibility", "visibility must be public, friends, or private");
    }

    private String normalizeRsvpStatus(String value) {
        return requireChoice(value, EVENT_RSVP_STATUSES, "status", "status must be going, interested, or declined");
    }

    private double normalizeCheckInRadius(Double radiusMeters) {
        return round2(normalizeBoundedDouble(radiusMeters, DEFAULT_CHECK_IN_RADIUS_METERS,
                10.0, 500.0, "checkInRadiusMeters"));
    }

    private double normalizeSearchRadius(Double radiusMeters) {
        return normalizePositiveDouble(radiusMeters, 500.0, MAX_SEARCH_RADIUS_METERS, "radiusMeters");
    }

    private int normalizeCapacity(Integer capacity) {
        return normalizeBoundedInt(capacity, 50, 1, 10_000, "capacity");
    }

    private List<String> normalizeStrings(List<String> values) {
        return normalizeUniqueStrings(values);
    }

    private int goingCount(String eventId) {
        return (int) repository.findAllRsvps().stream()
                .filter(rsvp -> rsvp.eventId().equals(eventId))
                .filter(rsvp -> "going".equals(rsvp.status()))
                .count();
    }

    private int interestedCount(String eventId) {
        return (int) repository.findAllRsvps().stream()
                .filter(rsvp -> rsvp.eventId().equals(eventId))
                .filter(rsvp -> "interested".equals(rsvp.status()))
                .count();
    }

    private int checkedInCount(String eventId) {
        return (int) repository.findAllCheckIns().stream()
                .filter(checkIn -> checkIn.eventId().equals(eventId))
                .count();
    }

    private int invitationCount(String eventId) {
        return (int) repository.findAllInvites().stream()
                .filter(invite -> invite.eventId().equals(eventId))
                .count();
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }
}
