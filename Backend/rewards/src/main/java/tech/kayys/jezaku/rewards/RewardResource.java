package tech.kayys.jezaku.rewards;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
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
import tech.kayys.jezaku.rewards.RewardDtos.BadgeCatalogResponse;
import tech.kayys.jezaku.rewards.RewardDtos.LeaderboardResponse;
import tech.kayys.jezaku.rewards.RewardDtos.RewardEventRequest;
import tech.kayys.jezaku.rewards.RewardDtos.RewardEventResponse;
import tech.kayys.jezaku.rewards.RewardDtos.RewardProfileResponse;
import tech.kayys.jezaku.rewards.RewardDtos.UserBadgesResponse;

@Path("/rewards")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class RewardResource {
    @Inject
    RewardService service;

    @POST
    @Path("/events")
    public Uni<Response> recordEvent(RewardEventRequest request) {
        return service.recordEvent(request)
                .map(event -> Response.status(Response.Status.CREATED).entity(event).build());
    }

    @GET
    @Path("/users/{userId}/profile")
    public Uni<RewardProfileResponse> profile(@PathParam("userId") String userId) {
        return service.profile(userId);
    }

    @GET
    @Path("/users/{userId}/badges")
    public Uni<UserBadgesResponse> userBadges(@PathParam("userId") String userId) {
        return service.userBadges(userId);
    }

    @GET
    @Path("/leaderboard")
    public Uni<LeaderboardResponse> leaderboard(
            @QueryParam("scope") @DefaultValue("global") String scope,
            @QueryParam("limit") @DefaultValue("20") Integer limit) {
        return service.leaderboard(scope, limit);
    }

    @GET
    @Path("/badges")
    public Uni<BadgeCatalogResponse> badges() {
        return service.badges();
    }
}
