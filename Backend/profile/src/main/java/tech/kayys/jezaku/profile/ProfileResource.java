package tech.kayys.jezaku.profile;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedUser;
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

    @Context
    ContainerRequestContext requestContext;

    private void self(String userId) {
        AuthContext.requireSelf(requestContext, userId);
    }

    /** The authenticated caller, or {@code null} when anonymous (enforcement off). */
    private String caller() {
        return AuthContext.user(requestContext).map(AuthenticatedUser::userId).orElse(null);
    }

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
        self(userId);
        if (request == null || request.parentalControls() == null) {
            return service.upsert(userId, request);
        }
        // Supplying parental controls through the profile body is a parental-controls change like any other.
        return service.existingParentalControls(userId).flatMap(current -> {
            requireMayChange(userId, current);
            return service.upsert(userId, request);
        });
    }

    @GET
    @Path("/{userId}/privacy")
    public Uni<PrivacySettings> privacy(@PathParam("userId") String userId) {
        self(userId);
        return service.privacy(userId);
    }

    @PUT
    @Path("/{userId}/privacy")
    public Uni<PrivacySettings> updatePrivacy(
            @PathParam("userId") String userId,
            PrivacySettings request) {
        self(userId);
        return service.updatePrivacy(userId, request);
    }

    @GET
    @Path("/{userId}/parental-controls")
    public Uni<ParentalControls> parentalControls(@PathParam("userId") String userId) {
        return service.existingParentalControls(userId).flatMap(current -> {
            if (!ProfileAccessPolicy.mayReadParentalControls(caller(), userId, current)) {
                throw new ForbiddenException("Only the account owner or guardian can view parental controls");
            }
            return service.parentalControls(userId);
        });
    }

    @PUT
    @Path("/{userId}/parental-controls")
    public Uni<ParentalControls> updateParentalControls(
            @PathParam("userId") String userId,
            ParentalControls request) {
        return service.existingParentalControls(userId).flatMap(current -> {
            requireMayChange(userId, current);
            return service.updateParentalControls(userId, request);
        });
    }

    private void requireMayChange(String userId, ParentalControls current) {
        if (!ProfileAccessPolicy.mayChangeParentalControls(caller(), userId, current)) {
            throw new ForbiddenException("Parental controls can only be changed by their guardian");
        }
    }

    @GET
    @Path("/search")
    public Uni<ProfileSearchResponse> search(@QueryParam("query") String query) {
        return service.search(query);
    }
}
