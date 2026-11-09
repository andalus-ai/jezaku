package tech.kayys.jezaku.discovery;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.discovery.DiscoveryDtos.DiscoveryListResponse;
import tech.kayys.jezaku.discovery.DiscoveryDtos.FeedbackRequest;
import tech.kayys.jezaku.discovery.DiscoveryDtos.FeedbackResponse;
import tech.kayys.jezaku.discovery.DiscoveryDtos.SearchResponse;

@Path("/discovery")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class DiscoveryResource {
    @Inject
    DiscoveryService service;

    @GET
    @Path("/nearby")
    public Uni<DiscoveryListResponse> nearby(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("radiusMeters") @DefaultValue("500") Double radiusMeters,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("type") String type) {
        requireCoordinates(lat, lng);
        return service.nearby(lat, lng, radiusMeters, viewerId, type);
    }

    @GET
    @Path("/search")
    public Uni<SearchResponse> search(
            @QueryParam("q") String query,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("radiusMeters") @DefaultValue("1000") Double radiusMeters) {
        if (lat != null || lng != null) {
            requireCoordinates(lat, lng);
        }
        return service.search(query, lat, lng, radiusMeters);
    }

    @GET
    @Path("/trending")
    public Uni<DiscoveryListResponse> trending(
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("radiusMeters") @DefaultValue("1000") Double radiusMeters) {
        requireCoordinates(lat, lng);
        return service.trending(lat, lng, radiusMeters);
    }

    @GET
    @Path("/users/{userId}/for-you")
    public Uni<DiscoveryListResponse> forYou(
            @PathParam("userId") String userId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("radiusMeters") @DefaultValue("1000") Double radiusMeters) {
        requireCoordinates(lat, lng);
        return service.forYou(userId, lat, lng, radiusMeters);
    }

    @POST
    @Path("/feedback")
    public Uni<FeedbackResponse> feedback(FeedbackRequest request) {
        return service.feedback(request);
    }

    private void requireCoordinates(Double lat, Double lng) {
        if (lat == null || lng == null) {
            throw new BadRequestException("lat and lng query parameters are required");
        }
    }
}
