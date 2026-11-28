package tech.kayys.jezaku.commerce.resource;

import jakarta.ws.rs.*;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedUser;
import tech.kayys.jezaku.commerce.domain.MerchantEvidence;
import tech.kayys.jezaku.commerce.service.CommerceEvidenceSubmissionService;
import java.util.List;

@Path("/commerce/merchants/{merchantId}/verification/evidence")
@Consumes(MediaType.APPLICATION_JSON) @Produces(MediaType.APPLICATION_JSON)
public class CommerceEvidenceResource {
    @Context ContainerRequestContext requestContext;
    private final CommerceEvidenceSubmissionService submissions;
    public CommerceEvidenceResource(CommerceEvidenceSubmissionService submissions) { this.submissions = submissions; }

    @POST public Response submit(@PathParam("merchantId") String merchantId, SubmitEvidenceRequest request) {
        if (request == null) throw new BadRequestException("Request body is required");
        MerchantEvidence result = submissions.submit(actorId(), merchantId, request.mediaAssetId(), request.category());
        return Response.status(Response.Status.CREATED).entity(result).build();
    }
    @GET public List<MerchantEvidence> list(@PathParam("merchantId") String merchantId) {
        return submissions.list(actorId(), merchantId);
    }
    private String actorId() {
        return AuthContext.user(requestContext).map(AuthenticatedUser::userId)
                .orElseThrow(() -> new NotAuthorizedException("Authenticated user required"));
    }
    public record SubmitEvidenceRequest(String mediaAssetId, MerchantEvidence.Category category) {}
}