package tech.kayys.jezaku.social;

import io.smallrye.mutiny.Uni;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDashboardResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAdvertiserDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdBillingLedgerResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreativeReviewRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignMetricsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignStatusUpdateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDailyReportResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdDeliveryResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAdEventCreateRequest;

@Path("/social/monetization")
@Produces(MediaType.APPLICATION_JSON)
public class SocialMonetizationResource {
    @Inject
    SocialMonetizationService service;

    @POST
    @Path("/ad-audience/preview")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialAdAudiencePreviewResponse> adAudiencePreview(SocialAdAudiencePreviewRequest request) {
        return service.adAudiencePreview(request);
    }

    @POST
    @Path("/ad-campaigns")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createAdCampaign(SocialAdCampaignCreateRequest request) {
        return service.createAdCampaign(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/ad-campaigns")
    public Uni<SocialAdCampaignListResponse> adCampaigns(
            @QueryParam("advertiserId") String advertiserId,
            @QueryParam("status") @DefaultValue("all") String status,
            @QueryParam("limit") @DefaultValue("20") Integer limit) {
        return service.adCampaigns(advertiserId, status, limit);
    }

    @GET
    @Path("/advertisers/{advertiserId}/dashboard")
    public Uni<SocialAdAdvertiserDashboardResponse> adAdvertiserDashboard(
            @PathParam("advertiserId") String advertiserId,
            @QueryParam("status") @DefaultValue("all") String status,
            @QueryParam("limit") @DefaultValue("20") Integer limit) {
        return service.adAdvertiserDashboard(advertiserId, status, limit);
    }

    @GET
    @Path("/advertisers/{advertiserId}/daily-report")
    public Uni<SocialAdAdvertiserDailyReportResponse> adAdvertiserDailyReport(
            @PathParam("advertiserId") String advertiserId,
            @QueryParam("status") @DefaultValue("all") String status,
            @QueryParam("days") @DefaultValue("7") Integer days,
            @QueryParam("limit") @DefaultValue("20") Integer limit) {
        return service.adAdvertiserDailyReport(advertiserId, status, days, limit);
    }

    @GET
    @Path("/ad-campaigns/{campaignId}")
    public Uni<SocialAdCampaignResponse> adCampaign(
            @PathParam("campaignId") String campaignId,
            @QueryParam("advertiserId") String advertiserId) {
        return service.adCampaign(campaignId, advertiserId);
    }

    @GET
    @Path("/ad-campaigns/{campaignId}/metrics")
    public Uni<SocialAdCampaignMetricsResponse> adCampaignMetrics(
            @PathParam("campaignId") String campaignId,
            @QueryParam("advertiserId") String advertiserId) {
        return service.adCampaignMetrics(campaignId, advertiserId);
    }

    @GET
    @Path("/ad-campaigns/{campaignId}/daily-report")
    public Uni<SocialAdDailyReportResponse> adCampaignDailyReport(
            @PathParam("campaignId") String campaignId,
            @QueryParam("advertiserId") String advertiserId,
            @QueryParam("days") @DefaultValue("7") Integer days) {
        return service.adCampaignDailyReport(campaignId, advertiserId, days);
    }

    @GET
    @Path("/ad-campaigns/{campaignId}/billing-ledger")
    public Uni<SocialAdBillingLedgerResponse> adCampaignBillingLedger(
            @PathParam("campaignId") String campaignId,
            @QueryParam("advertiserId") String advertiserId,
            @QueryParam("limit") @DefaultValue("100") Integer limit) {
        return service.adCampaignBillingLedger(campaignId, advertiserId, limit);
    }

    @PUT
    @Path("/ad-campaigns/{campaignId}/status")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialAdCampaignResponse> updateAdCampaignStatus(
            @PathParam("campaignId") String campaignId,
            SocialAdCampaignStatusUpdateRequest request) {
        return service.updateAdCampaignStatus(campaignId, request);
    }

    @PUT
    @Path("/ad-campaigns/{campaignId}/creative-review")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SocialAdCampaignResponse> updateAdCampaignCreativeReview(
            @PathParam("campaignId") String campaignId,
            SocialAdCampaignCreativeReviewRequest request) {
        return service.updateAdCampaignCreativeReview(campaignId, request);
    }

    @GET
    @Path("/ad-delivery")
    public Uni<SocialAdDeliveryResponse> adDelivery(
            @QueryParam("viewerId") String viewerId,
            @QueryParam("placement") @DefaultValue("feed") String placement,
            @QueryParam("limit") @DefaultValue("3") Integer limit) {
        return service.adDelivery(viewerId, placement, limit);
    }

    @POST
    @Path("/ad-events")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createAdEvent(SocialAdEventCreateRequest request) {
        return service.createAdEvent(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }
}
