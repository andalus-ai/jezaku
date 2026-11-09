package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Multi;
import io.smallrye.common.annotation.Blocking;
import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimap;
import tech.kayys.jezaku.camera.CameraDtos.CameraMinimapExpansion;
import tech.kayys.jezaku.camera.CameraDtos.CameraNearbyMemoryFeed;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionCreateRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEndRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionHeartbeatRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionPauseRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResumeRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionUpdateRequest;

import java.time.Instant;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;

@Path("/camera")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class CameraResource {
    @Inject
    CameraContextService service;

    @Inject
    CameraLiveSessionService liveSessions;

    @Inject
    CameraContextDeltaService contextDeltas;

    @Inject
    CameraSessionContextQueries sessionContexts;

    @Inject
    CameraSessionSyncService sessionSyncs;

    @GET
    @Path("/capabilities")
    public Response capabilities(@HeaderParam("If-None-Match") String ifNoneMatch) {
        if (CameraSessionSyncCapabilityCatalog.matchesHttpEtag(ifNoneMatch)) {
            return capabilitiesResponse(Response.status(Response.Status.NOT_MODIFIED)).build();
        }
        return capabilitiesResponse(Response.ok(CameraSessionSyncCapabilityCatalog.current())).build();
    }

    private Response.ResponseBuilder capabilitiesResponse(Response.ResponseBuilder builder) {
        return builder
                .header("ETag", CameraSessionSyncCapabilityCatalog.httpEtag())
                .header("Cache-Control", CameraSessionSyncCapabilityCatalog.cacheControlHeader());
    }

    @GET
    @Path("/context")
    public Uni<CameraContextResponse> context(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("speedMetersPerSecond") Double speedMetersPerSecond,
            @QueryParam("gpsAccuracyMeters") Double gpsAccuracyMeters,
            @QueryParam("altitudeAccuracyMeters") Double altitudeAccuracyMeters,
            @QueryParam("headingAccuracyDegrees") Double headingAccuracyDegrees,
            @QueryParam("compassAccuracyDegrees") Double compassAccuracyDegrees,
            @QueryParam("motionState") String motionState,
            @QueryParam("radiusMeters") @DefaultValue(CameraSyncContract.DEFAULT_RADIUS_METERS_QUERY)
                    Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("layers") String layers) {
        return contextFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                layers);
    }

    @GET
    @Path("/minimap")
    public Uni<CameraMinimap> minimap(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("speedMetersPerSecond") Double speedMetersPerSecond,
            @QueryParam("gpsAccuracyMeters") Double gpsAccuracyMeters,
            @QueryParam("altitudeAccuracyMeters") Double altitudeAccuracyMeters,
            @QueryParam("headingAccuracyDegrees") Double headingAccuracyDegrees,
            @QueryParam("compassAccuracyDegrees") Double compassAccuracyDegrees,
            @QueryParam("motionState") String motionState,
            @QueryParam("radiusMeters") @DefaultValue(CameraSyncContract.DEFAULT_RADIUS_METERS_QUERY)
                    Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("minimapPinLimitPerLayer")
            @DefaultValue(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER_QUERY)
                    Integer minimapPinLimitPerLayer,
            @QueryParam("layers") String layers) {
        return minimapFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                minimapPinLimitPerLayer,
                layers);
    }

    @GET
    @Path("/minimap/expansion")
    public Uni<CameraMinimapExpansion> minimapExpansion(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("speedMetersPerSecond") Double speedMetersPerSecond,
            @QueryParam("gpsAccuracyMeters") Double gpsAccuracyMeters,
            @QueryParam("altitudeAccuracyMeters") Double altitudeAccuracyMeters,
            @QueryParam("headingAccuracyDegrees") Double headingAccuracyDegrees,
            @QueryParam("compassAccuracyDegrees") Double compassAccuracyDegrees,
            @QueryParam("motionState") String motionState,
            @QueryParam("radiusMeters") @DefaultValue(CameraSyncContract.DEFAULT_RADIUS_METERS_QUERY)
                    Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("minimapPinLimitPerLayer")
            @DefaultValue(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER_QUERY)
                    Integer minimapPinLimitPerLayer,
            @QueryParam("layers") String layers,
            @QueryParam("layer") String layer) {
        return minimapExpansionFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                minimapPinLimitPerLayer,
                layers,
                layer);
    }

    @GET
    @Path("/memories/nearby")
    public Uni<CameraNearbyMemoryFeed> nearbyMemories(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("speedMetersPerSecond") Double speedMetersPerSecond,
            @QueryParam("gpsAccuracyMeters") Double gpsAccuracyMeters,
            @QueryParam("altitudeAccuracyMeters") Double altitudeAccuracyMeters,
            @QueryParam("headingAccuracyDegrees") Double headingAccuracyDegrees,
            @QueryParam("compassAccuracyDegrees") Double compassAccuracyDegrees,
            @QueryParam("motionState") String motionState,
            @QueryParam("radiusMeters") @DefaultValue(CameraSyncContract.DEFAULT_RADIUS_METERS_QUERY)
                    Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("feedMode") @DefaultValue(CameraSyncContract.DEFAULT_NEARBY_MEMORY_FEED_MODE)
                    String feedMode,
            @QueryParam("ownerId") String ownerId,
            @QueryParam("includeNeedsRefinement") Boolean includeNeedsRefinement,
            @QueryParam("pageSize") Integer pageSize,
            @QueryParam("pageCursor") String pageCursor,
            @QueryParam("sortBy") String sortBy,
            @QueryParam("sortDirection") String sortDirection) {
        return nearbyMemoriesFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                feedMode,
                ownerId,
                includeNeedsRefinement,
                pageSize,
                pageCursor,
                sortBy,
                sortDirection);
    }

    @GET
    @Path("/ops/health")
    public Uni<CameraOpsHealthResponse> opsHealth(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("lat") Double lat,
            @QueryParam("lng") Double lng,
            @QueryParam("altitudeMeters") Double altitudeMeters,
            @QueryParam("headingDegrees") Double headingDegrees,
            @QueryParam("compassDegrees") Double compassDegrees,
            @QueryParam("speedMetersPerSecond") Double speedMetersPerSecond,
            @QueryParam("gpsAccuracyMeters") Double gpsAccuracyMeters,
            @QueryParam("altitudeAccuracyMeters") Double altitudeAccuracyMeters,
            @QueryParam("headingAccuracyDegrees") Double headingAccuracyDegrees,
            @QueryParam("compassAccuracyDegrees") Double compassAccuracyDegrees,
            @QueryParam("motionState") String motionState,
            @QueryParam("radiusMeters") @DefaultValue(CameraSyncContract.DEFAULT_RADIUS_METERS_QUERY)
                    Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("layers") String layers) {
        return contextFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                layers)
                .map(context -> CameraOpsHealthReports.from(context, Instant.now()));
    }

    private Uni<CameraMinimap> minimapFromQuery(
            String viewerId,
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            String motionState,
            Double radiusMeters,
            Integer limitPerLayer,
            Integer minimapPinLimitPerLayer,
            String layers) {
        return contextFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                layers)
                .map(context -> minimapFromContext(context, minimapPinLimitPerLayer));
    }

    private Uni<CameraMinimapExpansion> minimapExpansionFromQuery(
            String viewerId,
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            String motionState,
            Double radiusMeters,
            Integer limitPerLayer,
            Integer minimapPinLimitPerLayer,
            String layers,
            String layer) {
        return contextFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                layers)
                .map(context -> minimapExpansionFromContext(context, minimapPinLimitPerLayer, layer));
    }

    private Uni<CameraNearbyMemoryFeed> nearbyMemoriesFromQuery(
            String viewerId,
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            String motionState,
            Double radiusMeters,
            Integer limitPerLayer,
            String feedMode,
            String ownerId,
            Boolean includeNeedsRefinement,
            Integer pageSize,
            String pageCursor,
            String sortBy,
            String sortDirection) {
        CameraNearbyMemoryPaging.Request paging = CameraNearbyMemoryPaging.fromRaw(pageSize, pageCursor);
        CameraDtos.CameraNearbyMemoryFilter filter = CameraNearbyMemoryFilters.fromRaw(
                feedMode,
                ownerId,
                includeNeedsRefinement);
        CameraDtos.CameraNearbyMemorySort sort = CameraNearbyMemorySorts.fromRaw(sortBy, sortDirection);
        CameraNearbyMemoryFeedLinksBuilder.StandaloneRequest linksRequest =
                new CameraNearbyMemoryFeedLinksBuilder.StandaloneRequest(
                        viewerId,
                        lat,
                        lng,
                        altitudeMeters,
                        headingDegrees,
                        compassDegrees,
                        speedMetersPerSecond,
                        gpsAccuracyMeters,
                        altitudeAccuracyMeters,
                        headingAccuracyDegrees,
                        compassAccuracyDegrees,
                        motionState,
                        radiusMeters,
                        limitPerLayer);
        return contextFromQuery(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                CameraNearbyMemoryPaging.sourceLimit(limitPerLayer, paging),
                "memories")
                .map(context -> {
                    CameraNearbyMemoryPaging.validateScope(paging, context, filter, sort);
                    return CameraNearbyMemoryFeeds.from(context, filter, paging, sort);
                })
                .map(feed -> CameraNearbyMemoryFeeds.withLinks(
                        feed,
                        CameraNearbyMemoryFeedLinksBuilder.standalone(feed, linksRequest)));
    }

    private CameraMinimap minimapFromContext(CameraContextResponse context, Integer minimapPinLimitPerLayer) {
        int pinLimit = normalizeBoundedInt(
                minimapPinLimitPerLayer,
                CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER,
                CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER,
                "minimapPinLimitPerLayer");
        return CameraMinimapViewports.from(
                context.telemetry(),
                context.summary(),
                context.layers(),
                context.totalDots(),
                pinLimit);
    }

    private CameraMinimapExpansion minimapExpansionFromContext(
            CameraContextResponse context,
            Integer minimapPinLimitPerLayer,
            String layer) {
        int pinLimit = normalizeBoundedInt(
                minimapPinLimitPerLayer,
                CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER,
                CameraSyncContract.MIN_MINIMAP_PIN_LIMIT_PER_LAYER,
                CameraSyncContract.MAX_MINIMAP_PIN_LIMIT_PER_LAYER,
                "minimapPinLimitPerLayer");
        return CameraMinimapViewports.expansion(
                context.telemetry(),
                context.layers(),
                pinLimit,
                layer);
    }

    private Uni<CameraContextResponse> contextFromQuery(
            String viewerId,
            Double lat,
            Double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            String motionState,
            Double radiusMeters,
            Integer limitPerLayer,
            String layers) {
        if (lat == null || lng == null) {
            throw new BadRequestException("lat and lng query parameters are required");
        }
        return service.context(
                viewerId,
                lat,
                lng,
                altitudeMeters,
                headingDegrees,
                compassDegrees,
                speedMetersPerSecond,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                motionState,
                radiusMeters,
                limitPerLayer,
                layers);
    }

    @POST
    @Path("/sessions")
    public Uni<Response> createSession(CameraSessionCreateRequest request) {
        return liveSessions.create(request)
                .map(session -> Response.status(Response.Status.CREATED).entity(session).build());
    }

    @GET
    @Path("/sessions/{sessionId}")
    public Uni<CameraSessionResponse> getSession(@PathParam("sessionId") String sessionId) {
        return liveSessions.get(sessionId);
    }

    @GET
    @Path("/sessions/{sessionId}/context")
    public Uni<CameraContextResponse> sessionContext(
            @PathParam("sessionId") String sessionId,
            @QueryParam("radiusMeters") Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("layers") String layers) {
        CameraSessionRecord session = liveSessions.activeSession(sessionId, Instant.now());
        return sessionContexts.forSession(session, radiusMeters, limitPerLayer, layers);
    }

    @GET
    @Path("/sessions/{sessionId}/minimap")
    public Uni<CameraMinimap> sessionMinimap(
            @PathParam("sessionId") String sessionId,
            @QueryParam("radiusMeters") Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("minimapPinLimitPerLayer")
            @DefaultValue(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER_QUERY)
                    Integer minimapPinLimitPerLayer,
            @QueryParam("layers") String layers) {
        CameraSessionRecord session = liveSessions.activeSession(sessionId, Instant.now());
        return sessionContexts.forSession(session, radiusMeters, limitPerLayer, layers)
                .map(context -> minimapFromContext(context, minimapPinLimitPerLayer));
    }

    @GET
    @Path("/sessions/{sessionId}/minimap/expansion")
    public Uni<CameraMinimapExpansion> sessionMinimapExpansion(
            @PathParam("sessionId") String sessionId,
            @QueryParam("radiusMeters") Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("minimapPinLimitPerLayer")
            @DefaultValue(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER_QUERY)
                    Integer minimapPinLimitPerLayer,
            @QueryParam("layers") String layers,
            @QueryParam("layer") String layer) {
        CameraSessionRecord session = liveSessions.activeSession(sessionId, Instant.now());
        return sessionContexts.forSession(session, radiusMeters, limitPerLayer, layers)
                .map(context -> minimapExpansionFromContext(context, minimapPinLimitPerLayer, layer));
    }

    @GET
    @Path("/sessions/{sessionId}/memories/nearby")
    public Uni<CameraNearbyMemoryFeed> sessionNearbyMemories(
            @PathParam("sessionId") String sessionId,
            @QueryParam("radiusMeters") Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("feedMode") @DefaultValue(CameraSyncContract.DEFAULT_NEARBY_MEMORY_FEED_MODE)
                    String feedMode,
            @QueryParam("ownerId") String ownerId,
            @QueryParam("includeNeedsRefinement") Boolean includeNeedsRefinement,
            @QueryParam("pageSize") Integer pageSize,
            @QueryParam("pageCursor") String pageCursor,
            @QueryParam("sortBy") String sortBy,
            @QueryParam("sortDirection") String sortDirection) {
        CameraSessionRecord session = liveSessions.activeSession(sessionId, Instant.now());
        CameraNearbyMemoryPaging.Request paging = CameraNearbyMemoryPaging.fromRaw(pageSize, pageCursor);
        CameraDtos.CameraNearbyMemoryFilter filter = CameraNearbyMemoryFilters.fromRaw(
                feedMode,
                ownerId,
                includeNeedsRefinement);
        CameraDtos.CameraNearbyMemorySort sort = CameraNearbyMemorySorts.fromRaw(sortBy, sortDirection);
        CameraNearbyMemoryFeedLinksBuilder.SessionRequest linksRequest =
                new CameraNearbyMemoryFeedLinksBuilder.SessionRequest(
                        sessionId,
                        radiusMeters,
                        limitPerLayer);
        return sessionContexts.forSession(
                session,
                radiusMeters,
                CameraNearbyMemoryPaging.sourceLimit(limitPerLayer, paging),
                "memories")
                .map(context -> {
                    CameraNearbyMemoryPaging.validateScope(paging, context, filter, sort);
                    return CameraNearbyMemoryFeeds.from(context, filter, paging, sort);
                })
                .map(feed -> CameraNearbyMemoryFeeds.withLinks(
                        feed,
                        CameraNearbyMemoryFeedLinksBuilder.session(feed, linksRequest)));
    }

    @GET
    @Path("/sessions/{sessionId}/sync")
    public Uni<CameraSessionSyncResponse> sessionSync(
            @PathParam("sessionId") String sessionId,
            @QueryParam("radiusMeters") Double radiusMeters,
            @QueryParam("limitPerLayer") @DefaultValue(CameraSyncContract.DEFAULT_LIMIT_PER_LAYER_QUERY)
                    Integer limitPerLayer,
            @QueryParam("minimapPinLimitPerLayer")
            @DefaultValue(CameraSyncContract.DEFAULT_MINIMAP_PIN_LIMIT_PER_LAYER_QUERY)
                    Integer minimapPinLimitPerLayer,
            @QueryParam("layers") String layers,
            @QueryParam("eventLimit") @DefaultValue(CameraSyncContract.DEFAULT_EVENT_LIMIT_QUERY)
                    Integer eventLimit,
            @QueryParam("afterSequence") @DefaultValue(CameraSyncContract.DEFAULT_CURSOR_QUERY)
                    Long afterSequence,
            @QueryParam("contextDeltaLimit") @DefaultValue(CameraSyncContract.DEFAULT_CONTEXT_DELTA_LIMIT_QUERY)
                    Integer contextDeltaLimit,
            @QueryParam("capabilitiesMode") @DefaultValue(CameraSyncContract.DEFAULT_CAPABILITIES_MODE_QUERY)
                    String capabilitiesMode,
            @QueryParam("capabilitiesEtag") String capabilitiesEtag,
            @QueryParam("sections") @DefaultValue(CameraSyncContract.DEFAULT_SYNC_RESPONSE_SECTIONS_QUERY)
                    String sections) {
        return sessionSyncs.sync(CameraSessionSyncRequest.fromRaw(
                sessionId,
                radiusMeters,
                limitPerLayer,
                minimapPinLimitPerLayer,
                layers,
                eventLimit,
                afterSequence,
                contextDeltaLimit,
                capabilitiesMode,
                capabilitiesEtag,
                sections));
    }

    @GET
    @Path("/sessions/{sessionId}/events")
    public Uni<CameraSessionEventListResponse> sessionEvents(
            @PathParam("sessionId") String sessionId,
            @QueryParam("limit") @DefaultValue(CameraSyncContract.DEFAULT_EVENT_LIMIT_QUERY) Integer limit,
            @QueryParam("afterSequence") @DefaultValue(CameraSyncContract.DEFAULT_CURSOR_QUERY)
                    Long afterSequence) {
        return liveSessions.events(sessionId, limit, afterSequence);
    }

    @GET
    @Path("/sessions/{sessionId}/stream")
    @Produces("text/event-stream")
    public Multi<CameraSessionEventResponse> sessionEventStream(
            @PathParam("sessionId") String sessionId,
            @QueryParam("maxEvents") @DefaultValue(CameraSyncContract.DEFAULT_STREAM_EVENT_LIMIT_QUERY)
                    Integer maxEvents,
            @QueryParam("afterSequence") @DefaultValue(CameraSyncContract.DEFAULT_CURSOR_QUERY)
                    Long afterSequence) {
        return liveSessions.streamEvents(sessionId, maxEvents, afterSequence);
    }

    @POST
    @Path("/sessions/{sessionId}/heartbeat")
    public Uni<CameraSessionResponse> heartbeatSession(
            @PathParam("sessionId") String sessionId,
            CameraSessionHeartbeatRequest request) {
        return liveSessions.heartbeat(sessionId, request);
    }

    @POST
    @Path("/sessions/{sessionId}/pause")
    public Uni<CameraSessionResponse> pauseSession(
            @PathParam("sessionId") String sessionId,
            CameraSessionPauseRequest request) {
        return liveSessions.pause(sessionId, request)
                .invoke(response -> contextDeltas.clear(sessionId));
    }

    @POST
    @Path("/sessions/{sessionId}/resume")
    public Uni<CameraSessionResponse> resumeSession(
            @PathParam("sessionId") String sessionId,
            CameraSessionResumeRequest request) {
        return liveSessions.resume(sessionId, request);
    }

    @POST
    @Path("/sessions/{sessionId}/end")
    public Uni<CameraSessionResponse> endSession(
            @PathParam("sessionId") String sessionId,
            CameraSessionEndRequest request) {
        return liveSessions.end(sessionId, request)
                .invoke(response -> contextDeltas.clear(sessionId));
    }

    @PATCH
    @Path("/sessions/{sessionId}")
    public Uni<CameraSessionResponse> updateSession(
            @PathParam("sessionId") String sessionId,
            CameraSessionUpdateRequest request) {
        return liveSessions.update(sessionId, request)
                .invoke(response -> {
                    if (!response.active()) {
                        contextDeltas.clear(sessionId);
                    }
                });
    }

}
