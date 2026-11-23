package tech.kayys.jezaku.safety;

import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.auth.AuthContext;
import tech.kayys.jezaku.auth.AuthenticatedService;
import tech.kayys.jezaku.auth.AuthenticatedUser;
import tech.kayys.jezaku.auth.ServiceScopes;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.EvaluationRequest;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.EvaluationBatchItem;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.EvaluationBatchRequest;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.EvaluationBatchResponse;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.EvaluationResponse;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.RestrictionCreateRequest;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.RestrictionRevokeRequest;
import tech.kayys.jezaku.safety.SpatialSafetyDtos.RestrictionUpdateRequest;

import java.util.List;
import java.util.Optional;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.UUID;

@Path("/safety/spatial")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class SpatialSafetyResource extends tech.kayys.jezaku.auth.CallerAwareResource {
    @Inject SpatialSafetyService service;
    @Inject SpatialSafetyEnforcer enforcer;
    @Inject SpatialPolicyRepository repository;

    @POST @Path("/restrictions")
    public Response create(RestrictionCreateRequest request) {
        Caller caller = requireCaller();
        SpatialRestriction created = service.create(caller.principal(), caller.actorId(), request);
        return Response.status(Response.Status.CREATED).entity(new SpatialSafetyDtos.RestrictionResponse(created)).build();
    }

    @PUT @Path("/restrictions/{restrictionId}")
    public SpatialSafetyDtos.RestrictionResponse update(@PathParam("restrictionId") String restrictionId, RestrictionUpdateRequest request) {
        Caller caller = requireCaller();
        return new SpatialSafetyDtos.RestrictionResponse(service.update(caller.principal(), caller.actorId(), restrictionId, request));
    }

    @POST @Path("/restrictions/{restrictionId}/revoke")
    public SpatialSafetyDtos.RestrictionResponse revoke(@PathParam("restrictionId") String restrictionId, RestrictionRevokeRequest request) {
        Caller caller = requireCaller();
        return new SpatialSafetyDtos.RestrictionResponse(service.revoke(caller.principal(), caller.actorId(), restrictionId, request));
    }

    @GET @Path("/restrictions/{restrictionId}")
    public SpatialSafetyDtos.RestrictionResponse get(@PathParam("restrictionId") String restrictionId) {
        return new SpatialSafetyDtos.RestrictionResponse(service.get(restrictionId));
    }

    @GET @Path("/restrictions/{restrictionId}/history")
    public SpatialSafetyDtos.RestrictionHistoryResponse history(@PathParam("restrictionId") String restrictionId) {
        Caller caller = requireCaller();
        return service.history(caller.principal(), restrictionId);
    }

    @POST @Path("/evaluate")
    public EvaluationResponse evaluate(EvaluationRequest request) {
        AuthContext.requireService(requestContext, ServiceScopes.SPATIAL_POLICY_EVALUATE);
        return service.evaluate(request);
    }

    @POST @Path("/evaluate/batch")
    public EvaluationBatchResponse evaluateBatch(EvaluationBatchRequest request) {
        AuthContext.requireService(requestContext, ServiceScopes.SPATIAL_POLICY_EVALUATE);
        if (request == null || request.requests() == null || request.requests().isEmpty()) {
            throw new BadRequestException("At least one evaluation request is required");
        }
        if (request.requests().size() > SpatialSafetyEnforcer.MAX_BATCH_SIZE) {
            throw new BadRequestException("Batch size must not exceed " + SpatialSafetyEnforcer.MAX_BATCH_SIZE);
        }
        List<SpatialSafetyEnforcer.EvaluationTarget> targets = request.requests().stream().map(this::toTarget).toList();
        SpatialSafetyEnforcer.PolicySnapshot snapshot = enforcer.captureSnapshot();
        List<EvaluationResponse> results = enforcer.evaluateBatch(snapshot, targets).stream()
                .map(decision -> new EvaluationResponse(decision, snapshot.evaluatedAt())).toList();
        return new EvaluationBatchResponse(results, snapshot.evaluatedAt());
    }

    private SpatialSafetyEnforcer.EvaluationTarget toTarget(EvaluationBatchItem request) {
        if (request == null || request.latitude() == null || request.longitude() == null
                || request.activity() == null || request.activity() == SpatialRestriction.Activity.ALL) {
            throw new BadRequestException("A concrete activity is required for every batch item");
        }
        if (!Double.isFinite(request.latitude()) || request.latitude() < -90 || request.latitude() > 90
                || !Double.isFinite(request.longitude()) || request.longitude() < -180 || request.longitude() > 180) {
            throw new BadRequestException("Coordinates are outside valid latitude/longitude bounds");
        }
        return new SpatialSafetyEnforcer.EvaluationTarget(request.latitude(), request.longitude(), request.activity());
    }


    /**
     * Evaluates a small set of routing-provider alternatives as NAVIGATE operations.
     * Geometry is validated before reading policy; all alternatives share one snapshot.
     */
    @POST @Path("/evaluate/routes")
    public SpatialSafetyDtos.RouteEvaluationBatchResponse evaluateRoutes(
            SpatialSafetyDtos.RouteEvaluationBatchRequest request) {
        AuthContext.requireService(requestContext, ServiceScopes.SPATIAL_POLICY_EVALUATE);
        if (request == null || request.routes() == null || request.routes().isEmpty()) {
            throw new BadRequestException("At least one route candidate is required");
        }
        if (request.routes().size() > SpatialSafetyEnforcer.MAX_ROUTE_CANDIDATES) {
            throw new BadRequestException("Route candidate count must not exceed "
                    + SpatialSafetyEnforcer.MAX_ROUTE_CANDIDATES);
        }
        double corridorBuffer = request.corridorBufferMeters() == null ? 0.0 : request.corridorBufferMeters();
        if (!Double.isFinite(corridorBuffer) || corridorBuffer < 0
                || corridorBuffer > SpatialSafetyEnforcer.MAX_ROUTE_CORRIDOR_BUFFER_METERS) {
            throw new BadRequestException("corridorBufferMeters must be between 0 and "
                    + SpatialSafetyEnforcer.MAX_ROUTE_CORRIDOR_BUFFER_METERS);
        }

        HashSet<String> routeIds = new HashSet<>();
        int totalVertices = 0;
        List<PreparedRoute> routes = new ArrayList<>(request.routes().size());
        for (SpatialSafetyDtos.RouteCandidateRequest candidate : request.routes()) {
            if (candidate == null || candidate.routeId() == null || candidate.routeId().isBlank()
                    || candidate.routeId().length() > 64 || !routeIds.add(candidate.routeId())) {
                throw new BadRequestException("Every route requires a unique routeId of at most 64 characters");
            }
            if (candidate.points() == null || candidate.points().size() < 2
                    || candidate.points().size() > SpatialRouteGeometry.MAX_VERTICES) {
                throw new BadRequestException("Each route must contain 2 to "
                        + SpatialRouteGeometry.MAX_VERTICES + " vertices");
            }
            totalVertices += candidate.points().size();
            if (totalVertices > SpatialSafetyEnforcer.MAX_ROUTE_BATCH_VERTICES) {
                throw new BadRequestException("Combined route vertices must not exceed "
                        + SpatialSafetyEnforcer.MAX_ROUTE_BATCH_VERTICES);
            }
            List<SpatialRouteGeometry.Point> points = new ArrayList<>(candidate.points().size());
            for (SpatialSafetyDtos.RoutePointRequest point : candidate.points()) {
                if (point == null || point.latitude() == null || point.longitude() == null) {
                    throw new BadRequestException("Route vertices require latitude and longitude");
                }
                points.add(new SpatialRouteGeometry.Point(point.latitude(), point.longitude()));
            }
            try {
                SpatialRouteGeometry.validate(points, corridorBuffer);
            } catch (IllegalArgumentException exception) {
                throw new BadRequestException(exception.getMessage());
            }
            routes.add(new PreparedRoute(candidate.routeId(), List.copyOf(points)));
        }

        SpatialSafetyEnforcer.PolicySnapshot snapshot = enforcer.captureSnapshot();
        Instant maximumValidity = snapshot.evaluatedAt().plus(Duration.ofSeconds(15));
        List<SpatialSafetyDtos.RouteEvaluationResponse> results = new ArrayList<>(routes.size());
        Instant batchValidUntil = maximumValidity;
        for (PreparedRoute route : routes) {
            SpatialSafetyPolicy.RouteDecision decision = enforcer.evaluateRoute(snapshot, route.points(),
                    corridorBuffer, SpatialRestriction.Activity.NAVIGATE);
            Instant routeValidUntil = decision.validUntil() == null
                    || maximumValidity.isBefore(decision.validUntil())
                    ? maximumValidity : decision.validUntil();
            if (routeValidUntil.isBefore(batchValidUntil)) {
                batchValidUntil = routeValidUntil;
            }
            results.add(new SpatialSafetyDtos.RouteEvaluationResponse(route.routeId(), decision.outcome(),
                    decision.restrictionIds(), decision.reasonCode(), decision.affectedSegmentIndices(),
                    decision.permitsOperation(), routeValidUntil));
        }
        return new SpatialSafetyDtos.RouteEvaluationBatchResponse(
                UUID.randomUUID().toString(), snapshot.evaluatedAt(), batchValidUntil,
                List.copyOf(results), snapshot.revision());
    }

    private record PreparedRoute(String routeId, List<SpatialRouteGeometry.Point> points) { }

    private Caller requireCaller() {
        Optional<AuthenticatedUser> user = AuthContext.user(requestContext);
        Optional<AuthenticatedService> service = AuthContext.service(requestContext);
        String actorId = user.map(AuthenticatedUser::userId).orElseGet(() -> service.map(AuthenticatedService::name).orElse(null));
        if (actorId == null || actorId.isBlank()) throw new jakarta.ws.rs.NotAuthorizedException("Authenticated authority caller required");
        AuthorityPrincipal principal = repository.findAuthority(actorId)
                .orElseThrow(() -> new jakarta.ws.rs.ForbiddenException("No authority grant is registered for caller"));
        return new Caller(actorId, principal);
    }

    private record Caller(String actorId, AuthorityPrincipal principal) { }
}
