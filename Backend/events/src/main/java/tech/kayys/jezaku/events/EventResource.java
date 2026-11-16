package tech.kayys.jezaku.events;

import tech.kayys.jezaku.auth.CallerAwareResource;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.events.EventDtos.CheckInRequest;
import tech.kayys.jezaku.events.EventDtos.CheckInResponse;
import tech.kayys.jezaku.events.EventDtos.EventActivityHistoryResponse;
import tech.kayys.jezaku.events.EventDtos.EventCreateRequest;
import tech.kayys.jezaku.events.EventDtos.EventFeedResponse;
import tech.kayys.jezaku.events.EventDtos.EventResponse;
import tech.kayys.jezaku.events.EventDtos.InviteRequest;
import tech.kayys.jezaku.events.EventDtos.InviteResponse;
import tech.kayys.jezaku.events.EventDtos.RsvpRequest;
import tech.kayys.jezaku.events.EventDtos.RsvpResponse;

import java.util.List;

@Path("/events")
@Produces(MediaType.APPLICATION_JSON)
public class EventResource extends CallerAwareResource {
    @Inject
    EventService service;

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> create(EventCreateRequest request) {
        self(request == null ? null : request.organizerId());
        return service.create(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/{eventId}")
    public Uni<EventResponse> get(
            @PathParam("eventId") String eventId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.get(eventId, lat, lng);
    }

    @GET
    @Path("/nearby")
    public Uni<List<EventResponse>> nearby(
            @QueryParam("lat") double lat,
            @QueryParam("lng") double lng,
            @QueryParam("radiusMeters") Double radiusMeters,
            @QueryParam("category") String category) {
        return service.nearby(lat, lng, radiusMeters, category);
    }

    @GET
    @Path("/users/{userId}")
    public Uni<EventFeedResponse> userEvents(@PathParam("userId") String userId) {
        return service.userEvents(userId);
    }

    @GET
    @Path("/{eventId}/activity")
    public Uni<EventActivityHistoryResponse> activity(
            @PathParam("eventId") String eventId,
            @QueryParam("viewerUserId") String viewerUserId) {
        viewerUserId = viewer(viewerUserId);
        return service.activity(eventId, viewerUserId);
    }

    @POST
    @Path("/{eventId}/rsvp")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<RsvpResponse> rsvp(
            @PathParam("eventId") String eventId,
            RsvpRequest request) {
        self(request == null ? null : request.userId());
        return service.rsvp(eventId, request);
    }

    @POST
    @Path("/{eventId}/check-ins")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<CheckInResponse> checkIn(
            @PathParam("eventId") String eventId,
            CheckInRequest request) {
        self(request == null ? null : request.userId());
        return service.checkIn(eventId, request);
    }

    @POST
    @Path("/{eventId}/invites")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<List<InviteResponse>> invite(
            @PathParam("eventId") String eventId,
            InviteRequest request) {
        self(request == null ? null : request.inviterId());
        return service.invite(eventId, request);
    }

    @GET
    @Path("/invitations/{userId}")
    public Uni<List<InviteResponse>> invitations(@PathParam("userId") String userId) {
        self(userId);
        return service.invitations(userId);
    }

    @POST
    @Path("/{eventId}/cancel")
    public Uni<EventResponse> cancel(
            @PathParam("eventId") String eventId,
            @QueryParam("actorUserId") String actorUserId) {
        self(actorUserId);
        return service.cancel(eventId, actorUserId);
    }
}
