package tech.kayys.jezaku.spatial;

import io.smallrye.mutiny.Uni;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.spatial.SpatialDtos.AnchorCreateRequest;
import tech.kayys.jezaku.spatial.SpatialDtos.AnchorResponse;

import java.net.URI;
import java.util.List;

@Path("/spatial/anchors")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Blocking
public class AnchorResource {
    @Inject
    SpatialService service;

    @GET
    @Path("/nearby")
    public Uni<List<AnchorResponse>> nearbyAnchors(
            @QueryParam("lat") double latitude,
            @QueryParam("lng") double longitude,
            @DefaultValue("100") @QueryParam("radiusMeters") double radiusMeters) {
        return service.nearbyAnchors(latitude, longitude, radiusMeters);
    }

    @POST
    public Uni<Response> createAnchor(AnchorCreateRequest request) {
        return service.createAnchor(request)
                .map(anchor -> Response
                        .created(URI.create("/spatial/anchors/" + anchor.id()))
                        .entity(anchor)
                        .build());
    }
}
