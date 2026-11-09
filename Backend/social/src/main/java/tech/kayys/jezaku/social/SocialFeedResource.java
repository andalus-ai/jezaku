package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.social.SocialDtos.SocialFeedResponse;

/**
 * Publishes the primary viewer feed endpoint for social content discovery.
 */
@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialFeedResource {
    @Inject
    SocialService service;

    @GET
    @Path("/feed")
    public Uni<SocialFeedResponse> feed(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.feed(viewerId, limit, cursor);
    }
}
