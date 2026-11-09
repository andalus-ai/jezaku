package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResponse;

/**
 * Exposes social search discovery across users, circles, content, and tags.
 */
@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialSearchResource {
    @Inject
    SocialService service;

    @GET
    @Path("/search")
    public Uni<SocialSearchResponse> search(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("q") String query,
            @QueryParam("types") String types,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.search(viewerId, query, types, limit, cursor);
    }
}
