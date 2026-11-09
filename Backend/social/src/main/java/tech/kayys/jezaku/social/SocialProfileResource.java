package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserProfileUpdateRequest;

/**
 * Handles user profile reads and owner-driven profile updates.
 */
@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialProfileResource {
    @Inject
    SocialService service;

    @GET
    @Path("/users/{userId}/profile")
    public Uni<SocialUserProfileSummaryResponse> userProfile(
            @PathParam("userId") String userId,
            @QueryParam("viewerId") String viewerId) {
        return service.userProfile(userId, viewerId);
    }

    @PUT
    @Path("/users/{userId}/profile")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialUserProfileResponse> updateUserProfile(
            @PathParam("userId") String userId,
            SocialUserProfileUpdateRequest request) {
        return service.updateUserProfile(userId, request);
    }
}
