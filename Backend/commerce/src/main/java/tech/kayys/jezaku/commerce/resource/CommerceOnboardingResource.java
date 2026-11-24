package tech.kayys.jezaku.commerce.resource;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.NotAuthorizedException;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedUser;
import tech.kayys.jezaku.commerce.domain.Merchant;
import tech.kayys.jezaku.commerce.domain.MerchantMembership;
import tech.kayys.jezaku.commerce.service.CommerceOnboardingService;

import java.util.List;

@Path("/commerce/merchants")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class CommerceOnboardingResource {
    @Context
    ContainerRequestContext requestContext;

    private final CommerceOnboardingService onboarding;

    public CommerceOnboardingResource(CommerceOnboardingService onboarding) {
        this.onboarding = onboarding;
    }

    @POST
    public Response register(RegisterMerchantRequest request) {
        if (request == null) throw new IllegalArgumentException("Request body is required");
        Merchant merchant = onboarding.registerMerchant(actorId(), request.legalName(),
                request.displayName(), request.jurisdiction());
        return Response.status(Response.Status.CREATED).entity(merchant).build();
    }

    @POST
    @Path("/{merchantId}/memberships")
    public Response invite(@PathParam("merchantId") String merchantId, InviteMemberRequest request) {
        if (request == null) throw new IllegalArgumentException("Request body is required");
        MerchantMembership membership = onboarding.invite(actorId(), merchantId, request.userId(), request.role());
        return Response.status(Response.Status.CREATED).entity(membership).build();
    }

    @GET
    @Path("/{merchantId}/memberships")
    public List<MerchantMembership> list(@PathParam("merchantId") String merchantId) {
        return onboarding.listMemberships(actorId(), merchantId);
    }

    @POST
    @Path("/{merchantId}/memberships/{membershipId}/accept")
    public MerchantMembership accept(@PathParam("merchantId") String merchantId,
                                     @PathParam("membershipId") String membershipId) {
        return onboarding.acceptInvitation(actorId(), merchantId, membershipId);
    }

    @POST
    @Path("/{merchantId}/memberships/{membershipId}/revoke")
    public MerchantMembership revoke(@PathParam("merchantId") String merchantId,
                                     @PathParam("membershipId") String membershipId) {
        return onboarding.revoke(actorId(), merchantId, membershipId);
    }

    private String actorId() {
        AuthenticatedUser user = AuthContext.user(requestContext)
                .orElseThrow(() -> new NotAuthorizedException("Authenticated user required"));
        return user.userId();
    }

    public record RegisterMerchantRequest(String legalName, String displayName, String jurisdiction) {}
    public record InviteMemberRequest(String userId, MerchantMembership.Role role) {}
}
