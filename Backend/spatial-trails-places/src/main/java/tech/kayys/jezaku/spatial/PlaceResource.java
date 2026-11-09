package tech.kayys.jezaku.spatial;

import io.smallrye.mutiny.Uni;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.spatial.SpatialDtos.PlaceDetail;
import tech.kayys.jezaku.spatial.SpatialDtos.PlaceSummary;

import java.util.List;

@Path("/places")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Blocking
public class PlaceResource {
    @Inject
    SpatialService service;

    @GET
    @Path("/nearby")
    public Uni<List<PlaceSummary>> nearbyPlaces(
            @QueryParam("lat") double latitude,
            @QueryParam("lng") double longitude,
            @DefaultValue("250") @QueryParam("radiusMeters") double radiusMeters) {
        return service.nearbyPlaces(latitude, longitude, radiusMeters);
    }

    @GET
    @Path("/{placeId}")
    public Uni<PlaceDetail> placeDetail(@PathParam("placeId") String placeId) {
        return service.placeDetail(placeId);
    }
}
