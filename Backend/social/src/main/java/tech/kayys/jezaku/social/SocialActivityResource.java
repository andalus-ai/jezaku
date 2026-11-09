package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityMarkReadResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivityResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialActivitySummaryResponse;

/**
 * Serves activity inbox, outbox, unread summary, and read-state endpoints.
 */
@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialActivityResource {
    @Inject
    SocialService service;

    @GET
    @Path("/activity/{userId}")
    public Uni<SocialActivityListResponse> activities(
            @PathParam("userId") String userId,
            @QueryParam("mode") @DefaultValue("inbox") String mode,
            @QueryParam("limit") @DefaultValue("50") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.activities(userId, mode, limit, cursor);
    }

    @GET
    @Path("/activity/{userId}/summary")
    public Uni<SocialActivitySummaryResponse> activitySummary(@PathParam("userId") String userId) {
        return service.activitySummary(userId);
    }

    @PUT
    @Path("/activity/{activityId}/read")
    public Uni<SocialActivityResponse> markActivityRead(
            @PathParam("activityId") String activityId,
            @QueryParam("actorUserId") String actorUserId) {
        return service.markActivityRead(activityId, actorUserId);
    }

    @PUT
    @Path("/activity/{userId}/read-all")
    public Uni<SocialActivityMarkReadResponse> markAllActivitiesRead(@PathParam("userId") String userId) {
        return service.markAllActivitiesRead(userId);
    }
}
