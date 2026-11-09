package tech.kayys.jezaku.presence;

import io.smallrye.mutiny.Uni;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.presence.PresenceDtos.MinimapResponse;
import tech.kayys.jezaku.presence.PresenceDtos.NearbyPresenceResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceOpsHealthResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceResponse;
import tech.kayys.jezaku.presence.PresenceDtos.PresenceUpdateRequest;
import tech.kayys.jezaku.presence.PresenceDtos.VisibilityResponse;
import tech.kayys.jezaku.presence.PresenceDtos.VisibilityUpdateRequest;

@Path("/presence")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class PresenceResource {
    @Inject
    PresenceService service;

    @POST
    @Path("/check-ins")
    public Uni<Response> checkIn(PresenceUpdateRequest request) {
        return service.checkIn(request)
                .map(presence -> Response.status(Response.Status.CREATED).entity(presence).build());
    }

    @GET
    @Path("/nearby")
    public Uni<NearbyPresenceResponse> nearby(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("radiusMeters") @DefaultValue("100") Double radiusMeters,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("viewerId") String viewerId) {
        if (lat == null || lng == null) {
            throw new BadRequestException("lat and lng query parameters are required");
        }
        return service.nearby(lat, lng, altitudeMeters, headingDegrees, compassDegrees, radiusMeters, limit, viewerId);
    }

    @GET
    @Path("/users/{userId}")
    public Uni<PresenceResponse> get(
            @PathParam("userId") String userId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng) {
        return service.get(userId, lat, lng);
    }

    @GET
    @Path("/users/{userId}/minimap")
    public Uni<MinimapResponse> minimap(
            @PathParam("userId") String userId,
            @QueryParam("radiusMeters") @DefaultValue("100") Double radiusMeters,
            @QueryParam("limit") @DefaultValue("50") Integer limit) {
        return service.minimap(userId, radiusMeters, limit);
    }

    @PUT
    @Path("/users/{userId}/visibility")
    public Uni<VisibilityResponse> visibility(
            @PathParam("userId") String userId,
            VisibilityUpdateRequest request) {
        return service.visibility(userId, request);
    }

    @GET
    @Path("/ops/health")
    public Uni<PresenceOpsHealthResponse> opsHealth() {
        return service.opsHealth();
    }

    @DELETE
    @Path("/users/{userId}")
    public Uni<Response> delete(@PathParam("userId") String userId) {
        return service.delete(userId)
                .replaceWith(Response.noContent().build());
    }
}
