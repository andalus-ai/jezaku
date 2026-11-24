package tech.kayys.jezaku.commerce.resource;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.NotAuthorizedException;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedUser;
import tech.kayys.jezaku.commerce.domain.Merchant;
import tech.kayys.jezaku.commerce.service.CommerceMerchantReviewService;

@Path("/commerce/merchants/{merchantId}/review")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class CommerceMerchantReviewResource {
    @Context
    ContainerRequestContext requestContext;

    private final CommerceMerchantReviewService reviews;

    public CommerceMerchantReviewResource(CommerceMerchantReviewService reviews) {
        this.reviews = reviews;
    }

    @POST
    @Path("/verify")
    public Merchant verify(@PathParam("merchantId") String merchantId, ReviewRequest request) {
        return reviews.verify(actorId(), merchantId, reason(request));
    }

    @POST
    @Path("/reject")
    public Merchant reject(@PathParam("merchantId") String merchantId, ReviewRequest request) {
        return reviews.reject(actorId(), merchantId, reason(request));
    }

    @POST
    @Path("/suspend")
    public Merchant suspend(@PathParam("merchantId") String merchantId, ReviewRequest request) {
        return reviews.suspend(actorId(), merchantId, reason(request));
    }

    @POST
    @Path("/reinstate")
    public Merchant reinstate(@PathParam("merchantId") String merchantId, ReviewRequest request) {
        return reviews.reinstate(actorId(), merchantId, reason(request));
    }

    private String actorId() {
        AuthenticatedUser user = AuthContext.user(requestContext)
                .orElseThrow(() -> new NotAuthorizedException("Authenticated user required"));
        return user.userId();
    }

    private static String reason(ReviewRequest request) {
        if (request == null || request.reasonCode() == null || request.reasonCode().isBlank()) {
            throw new IllegalArgumentException("reasonCode is required");
        }
        return request.reasonCode();
    }

    public record ReviewRequest(String reasonCode) {}
}
