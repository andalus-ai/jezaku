package tech.kayys.jezaku.spatial;

import io.smallrye.mutiny.Uni;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.spatial.SpatialDtos.SaveTrailRequest;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailCompletionRequest;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailHistoryEntry;
import tech.kayys.jezaku.spatial.SpatialDtos.TrailHistoryResponse;

import java.net.URI;
import java.util.List;

@Path("/trails")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Blocking
public class TrailResource {
    @Inject
    SpatialService service;

    @POST
    @Path("/completions")
    public Uni<Response> recordCompletion(TrailCompletionRequest request) {
        return service.recordTrailCompletion(request)
                .map(trail -> Response
                        .created(URI.create("/trails/history/" + trail.userId() + "/" + trail.id()))
                        .entity(trail)
                        .build());
    }

    @GET
    @Path("/history/{userId}")
    public Uni<TrailHistoryResponse> history(@PathParam("userId") String userId) {
        return service.trailHistory(userId);
    }

    @DELETE
    @Path("/history/{userId}")
    public Uni<TrailHistoryResponse> clearHistory(@PathParam("userId") String userId) {
        return service.clearTrailHistory(userId);
    }

    @POST
    @Path("/saved")
    public Uni<TrailHistoryEntry> saveTrail(SaveTrailRequest request) {
        return service.saveTrail(request.userId(), request.trailId());
    }

    @GET
    @Path("/saved/{userId}")
    public Uni<List<TrailHistoryEntry>> savedTrails(@PathParam("userId") String userId) {
        return service.savedTrails(userId);
    }

    @DELETE
    @Path("/saved/{userId}/{trailId}")
    public Uni<Response> unsaveTrail(
            @PathParam("userId") String userId,
            @PathParam("trailId") String trailId) {
        return service.unsaveTrail(userId, trailId)
                .replaceWith(Response.noContent().build());
    }
}
