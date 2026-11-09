package tech.kayys.jezaku.journeys;

import io.smallrye.mutiny.Uni;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.journeys.JourneyDtos.CheckpointCompleteRequest;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyListResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyProgressResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.JourneyStartRequest;
import tech.kayys.jezaku.journeys.JourneyDtos.UserBadgesResponse;
import tech.kayys.jezaku.journeys.JourneyDtos.UserJourneysResponse;

@Path("/journeys")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class JourneyResource {
    @Inject
    JourneyService service;

    @GET
    public Uni<JourneyListResponse> list(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("radiusMeters") @DefaultValue("1000") Double radiusMeters,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("category") String category) {
        requireCoordinates(lat, lng);
        return service.list(lat, lng, radiusMeters, viewerId, category);
    }

    @GET
    @Path("/{journeyId}")
    public Uni<JourneyResponse> get(
            @PathParam("journeyId") String journeyId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.get(journeyId, lat, lng);
    }

    @POST
    @Path("/{journeyId}/start")
    public Uni<Response> start(
            @PathParam("journeyId") String journeyId,
            JourneyStartRequest request) {
        return service.start(journeyId, request)
                .map(progress -> Response.status(Response.Status.CREATED).entity(progress).build());
    }

    @POST
    @Path("/sessions/{sessionId}/checkpoints/{checkpointId}/complete")
    public Uni<JourneyProgressResponse> completeCheckpoint(
            @PathParam("sessionId") String sessionId,
            @PathParam("checkpointId") String checkpointId,
            CheckpointCompleteRequest request) {
        return service.completeCheckpoint(sessionId, checkpointId, request);
    }

    @POST
    @Path("/sessions/{sessionId}/abandon")
    public Uni<JourneyProgressResponse> abandon(
            @PathParam("sessionId") String sessionId,
            @QueryParam("userId") String userId) {
        return service.abandon(sessionId, userId);
    }

    @GET
    @Path("/users/{userId}")
    public Uni<UserJourneysResponse> userJourneys(@PathParam("userId") String userId) {
        return service.userJourneys(userId);
    }

    @GET
    @Path("/users/{userId}/badges")
    public Uni<UserBadgesResponse> userBadges(@PathParam("userId") String userId) {
        return service.userBadges(userId);
    }

    private void requireCoordinates(Double lat, Double lng) {
        if (lat == null || lng == null) {
            throw new BadRequestException("lat and lng query parameters are required");
        }
    }
}
