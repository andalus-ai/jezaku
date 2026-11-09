package tech.kayys.jezaku.safety;

import io.smallrye.mutiny.Uni;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.safety.SafetyDtos.ReportCreateRequest;
import tech.kayys.jezaku.safety.SafetyDtos.ReportListResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportQueueSummaryResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportReviewHistoryResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportReviewRequest;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneCheckRequest;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneCheckResponse;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneCreateRequest;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneListResponse;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneResponse;

@Path("/safety")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class SafetyResource {
    @Inject
    SafetyService service;

    @POST
    @Path("/reports")
    public Uni<Response> createReport(ReportCreateRequest request) {
        return service.createReport(request)
                .map(report -> Response.status(Response.Status.CREATED).entity(report).build());
    }

    @GET
    @Path("/reports")
    public Uni<ReportListResponse> reports(
            @QueryParam("status") String status,
            @QueryParam("targetType") String targetType,
            @QueryParam("reason") String reason,
            @QueryParam("targetUserId") String targetUserId) {
        return service.reports(status, targetType, reason, targetUserId);
    }

    @GET
    @Path("/reports/summary")
    public Uni<ReportQueueSummaryResponse> reportSummary() {
        return service.reportSummary();
    }

    @GET
    @Path("/reports/{reportId}")
    public Uni<ReportResponse> report(@PathParam("reportId") String reportId) {
        return service.report(reportId);
    }

    @PUT
    @Path("/reports/{reportId}/review")
    public Uni<ReportResponse> review(
            @PathParam("reportId") String reportId,
            ReportReviewRequest request) {
        return service.review(reportId, request);
    }

    @GET
    @Path("/reports/{reportId}/reviews")
    public Uni<ReportReviewHistoryResponse> reviewHistory(
            @PathParam("reportId") String reportId,
            @QueryParam("reviewerId") String reviewerId) {
        return service.reviewHistory(reportId, reviewerId);
    }

    @POST
    @Path("/zones")
    public Uni<Response> createZone(SafetyZoneCreateRequest request) {
        return service.createZone(request)
                .map(zone -> Response.status(Response.Status.CREATED).entity(zone).build());
    }

    @GET
    @Path("/zones/users/{userId}")
    public Uni<SafetyZoneListResponse> userZones(@PathParam("userId") String userId) {
        return service.userZones(userId);
    }

    @POST
    @Path("/zones/check")
    public Uni<SafetyZoneCheckResponse> checkZone(SafetyZoneCheckRequest request) {
        return service.checkZone(request);
    }

    @DELETE
    @Path("/zones/{zoneId}")
    public Uni<Response> deleteZone(
            @PathParam("zoneId") String zoneId,
            @QueryParam("guardianId") String guardianId) {
        return service.deleteZone(zoneId, guardianId)
                .replaceWith(Response.noContent().build());
    }
}
