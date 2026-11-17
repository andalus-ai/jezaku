package tech.kayys.jezaku.social;

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
import tech.kayys.jezaku.auth.CallerAwareResource;
import tech.kayys.jezaku.auth.ServiceScopes;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphRepositoryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNeighborhoodSummaryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

@Path("/social")
@Produces(MediaType.APPLICATION_JSON)
public class SocialGraphResource extends CallerAwareResource {
    @Inject
    SocialService service;

    @GET
    @Path("/graph/{userId}")
    public Uni<SocialGraphResponse> graph(@PathParam("userId") String userId) {
        selfOrService(userId, ServiceScopes.SOCIAL_AUDIENCE);
        return service.graph(userId);
    }

    @GET
    @Path("/network/{userId}")
    public Uni<SocialNetworkResponse> network(
            @PathParam("userId") String userId,
            @QueryParam("maxDepth") @DefaultValue("2") Integer maxDepth) {
        selfOrService(userId, ServiceScopes.SOCIAL_AUDIENCE);
        return service.network(userId, maxDepth);
    }

    @GET
    @Path("/neighborhood/{userId}")
    public Uni<SocialNeighborhoodSummaryResponse> neighborhood(
            @PathParam("userId") String userId,
            @QueryParam("maxDepth") @DefaultValue("2") Integer maxDepth,
            @QueryParam("limit") @DefaultValue("10") Integer limit) {
        selfOrService(userId, ServiceScopes.SOCIAL_AUDIENCE);
        return service.neighborhood(userId, maxDepth, limit);
    }

    @GET
    @Path("/audience/preview")
    public Uni<SocialAudiencePreviewResponse> audiencePreview(
            @QueryParam("ownerId") String ownerId,
            @QueryParam("scope") @DefaultValue("friends") String scope,
            @QueryParam("targetId") String targetId,
            @QueryParam("limit") @DefaultValue("50") Integer limit) {
        selfOrService(ownerId, ServiceScopes.SOCIAL_AUDIENCE);
        return service.audiencePreview(ownerId, scope, targetId, limit);
    }

    @GET
    @Path("/audience/decision")
    public Uni<SocialAudienceDecisionResponse> audienceDecision(
            @QueryParam("ownerId") String ownerId,
            @QueryParam("viewerId") String viewerId,
            @QueryParam("scope") @DefaultValue("friends") String scope,
            @QueryParam("targetId") String targetId) {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.audienceDecision(ownerId, viewerId, scope, targetId);
    }

    @POST
    @Path("/audience/decision/batch")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialAudienceDecisionBatchResponse> audienceDecisions(
            SocialAudienceDecisionBatchRequest request) {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.audienceDecisions(request);
    }

    @POST
    @Path("/audience/access")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialAudienceAccessResponse> audienceAccess(
            SocialAudienceAccessRequest request) {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.audienceAccess(request);
    }

    @GET
    @Path("/graph/repository")
    public Uni<SocialGraphRepositoryResponse> repositoryStatus() {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.repositoryStatus();
    }

    @GET
    @Path("/recommendations/{userId}")
    public Uni<SocialRecommendationsResponse> recommendations(
            @PathParam("userId") String userId,
            @QueryParam("limit") @DefaultValue("20") Integer limit,
            @QueryParam("cursor") String cursor) {
        return service.recommendations(userId, limit, cursor);
    }

    @GET
    @Path("/relationships/context")
    public Uni<SocialRelationshipContextResponse> relationshipContext(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("ownerId") String ownerId) {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.relationshipContext(viewerId, ownerId);
    }

    @POST
    @Path("/relationships/context/batch")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialRelationshipContextBatchResponse> relationshipContexts(
            SocialRelationshipContextBatchRequest request) {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.relationshipContexts(request);
    }

    @GET
    @Path("/relationships/path")
    public Uni<SocialConnectionPathResponse> connectionPath(
            @QueryParam("fromUserId") String fromUserId,
            @QueryParam("toUserId") String toUserId,
            @QueryParam("maxDepth") @DefaultValue("3") Integer maxDepth) {
        selfOrService(fromUserId, ServiceScopes.SOCIAL_AUDIENCE);
        return service.connectionPath(fromUserId, toUserId, maxDepth);
    }

    @GET
    @Path("/visibility")
    public Uni<VisibilityDecision> visibility(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("ownerId") String ownerId) {
        requireService(ServiceScopes.SOCIAL_AUDIENCE);
        return service.visibility(viewerId, ownerId);
    }
}
