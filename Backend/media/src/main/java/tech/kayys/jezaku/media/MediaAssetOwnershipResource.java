package tech.kayys.jezaku.media;

import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import tech.kayys.jezaku.auth.AuthContext;

@Path("/media/internal/assets")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class MediaAssetOwnershipResource {
    static final String REQUIRED_SCOPE = "commerce:media-ownership";

    @Inject
    MediaService service;

    @Context
    ContainerRequestContext requestContext;

    @POST
    @Path("/{mediaId}/merchant-evidence-ownership-check")
    public MediaDtos.MediaAssetOwnershipResponse checkMerchantEvidenceOwnership(
            @PathParam("mediaId") String mediaId,
            MediaDtos.MediaAssetOwnershipRequest request) {
        AuthContext.requireService(requestContext, REQUIRED_SCOPE);
        if (AuthContext.service(requestContext).filter(s -> s.hasScope(REQUIRED_SCOPE)).isEmpty()) {
            throw new jakarta.ws.rs.ForbiddenException("Authenticated service grant is required");
        }
        if (request == null || request.expectedOwnerId() == null || request.expectedOwnerId().isBlank()) {
            throw new jakarta.ws.rs.BadRequestException("expectedOwnerId is required");
        }
        return service.checkMerchantEvidenceOwnership(mediaId, request.expectedOwnerId()).await().indefinitely();
    }
}
