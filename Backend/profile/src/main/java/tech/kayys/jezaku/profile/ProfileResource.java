package tech.kayys.jezaku.profile;

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
import tech.kayys.jezaku.profile.ProfileDtos.ParentalControls;
import tech.kayys.jezaku.profile.ProfileDtos.PrivacySettings;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileResponse;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileSearchResponse;
import tech.kayys.jezaku.profile.ProfileDtos.ProfileUpsertRequest;

@Path("/profiles")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class ProfileResource {
    @Inject
    ProfileService service;

    @GET
    @Path("/{userId}")
    public Uni<ProfileResponse> get(@PathParam("userId") String userId) {
        return service.get(userId);
    }

    @PUT
    @Path("/{userId}")
    public Uni<ProfileResponse> upsert(
            @PathParam("userId") String userId,
            ProfileUpsertRequest request) {
        return service.upsert(userId, request);
    }

    @GET
    @Path("/{userId}/privacy")
    public Uni<PrivacySettings> privacy(@PathParam("userId") String userId) {
        return service.privacy(userId);
    }

    @PUT
    @Path("/{userId}/privacy")
    public Uni<PrivacySettings> updatePrivacy(
            @PathParam("userId") String userId,
            PrivacySettings request) {
        return service.updatePrivacy(userId, request);
    }

    @GET
    @Path("/{userId}/parental-controls")
    public Uni<ParentalControls> parentalControls(@PathParam("userId") String userId) {
        return service.parentalControls(userId);
    }

    @PUT
    @Path("/{userId}/parental-controls")
    public Uni<ParentalControls> updateParentalControls(
            @PathParam("userId") String userId,
            ParentalControls request) {
        return service.updateParentalControls(userId, request);
    }

    @GET
    @Path("/search")
    public Uni<ProfileSearchResponse> search(@QueryParam("query") String query) {
        return service.search(query);
    }
}
