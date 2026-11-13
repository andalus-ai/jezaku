package tech.kayys.jezaku.identity;

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
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.identity.IdentityDtos.AccountCreateRequest;
import tech.kayys.jezaku.identity.IdentityDtos.AccountResponse;
import tech.kayys.jezaku.identity.IdentityDtos.GuardianLinkApprovalRequest;
import tech.kayys.jezaku.identity.IdentityDtos.GuardianLinkCreateRequest;
import tech.kayys.jezaku.identity.IdentityDtos.GuardianLinkResponse;
import tech.kayys.jezaku.identity.IdentityDtos.IdentityOverviewResponse;
import tech.kayys.jezaku.identity.IdentityDtos.LoginRequest;
import tech.kayys.jezaku.identity.IdentityDtos.RefreshSessionRequest;
import tech.kayys.jezaku.identity.IdentityDtos.SessionResponse;
import tech.kayys.jezaku.identity.IdentityDtos.SessionValidationResponse;
import tech.kayys.jezaku.identity.IdentityDtos.TrustedDeviceRequest;
import tech.kayys.jezaku.identity.IdentityDtos.TrustedDeviceResponse;

import tech.kayys.jezaku.auth.AuthContext;

import java.util.List;

@Path("/identity")
@Produces(MediaType.APPLICATION_JSON)
@Blocking
public class IdentityResource {
    @Inject
    IdentityService service;

    @Context
    ContainerRequestContext requestContext;

    /** Callers may only read or change their own identity data; see {@link AuthContext#requireSelf}. */
    private void self(String userId) {
        AuthContext.requireSelf(requestContext, userId);
    }

    @POST
    @Path("/accounts")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createAccount(AccountCreateRequest request) {
        return service.createAccount(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @GET
    @Path("/accounts/{userId}")
    public Uni<AccountResponse> account(@PathParam("userId") String userId) {
        self(userId);
        return service.account(userId);
    }

    @PUT
    @Path("/accounts/{userId}/status")
    public Uni<AccountResponse> updateStatus(
            @PathParam("userId") String userId,
            @QueryParam("status") String status) {
        self(userId);
        return service.updateStatus(userId, status);
    }

    @POST
    @Path("/sessions")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SessionResponse> login(LoginRequest request) {
        return service.login(request);
    }

    @POST
    @Path("/sessions/refresh")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<SessionResponse> refresh(RefreshSessionRequest request) {
        return service.refresh(request);
    }

    @GET
    @Path("/sessions/validate")
    public Uni<SessionValidationResponse> validate(@QueryParam("accessToken") String accessToken) {
        return service.validate(accessToken);
    }

    @GET
    @Path("/sessions/{userId}")
    public Uni<List<SessionResponse>> sessions(@PathParam("userId") String userId) {
        self(userId);
        return service.sessions(userId);
    }

    @DELETE
    @Path("/sessions/{userId}/{sessionId}")
    public Uni<Response> revoke(
            @PathParam("userId") String userId,
            @PathParam("sessionId") String sessionId) {
        self(userId);
        return service.revoke(userId, sessionId)
                .replaceWith(Response.noContent().build());
    }

    @POST
    @Path("/guardian-links")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> createGuardianLink(GuardianLinkCreateRequest request) {
        if (request != null) {
            self(request.childUserId());
        }
        return service.createGuardianLink(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @POST
    @Path("/guardian-links/{linkId}/approve")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<GuardianLinkResponse> approveGuardianLink(
            @PathParam("linkId") String linkId,
            GuardianLinkApprovalRequest request) {
        if (request != null) {
            self(request.guardianUserId());
        }
        return service.approveGuardianLink(linkId, request);
    }

    @GET
    @Path("/guardian-links/{userId}")
    public Uni<List<GuardianLinkResponse>> guardianLinks(@PathParam("userId") String userId) {
        self(userId);
        return service.guardianLinks(userId);
    }

    @PUT
    @Path("/devices")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<TrustedDeviceResponse> trustDevice(TrustedDeviceRequest request) {
        if (request != null) {
            self(request.userId());
        }
        return service.trustDevice(request);
    }

    @GET
    @Path("/devices/{userId}")
    public Uni<List<TrustedDeviceResponse>> trustedDevices(@PathParam("userId") String userId) {
        self(userId);
        return service.trustedDevices(userId);
    }

    @DELETE
    @Path("/devices/{userId}/{deviceId}")
    public Uni<Response> untrustDevice(
            @PathParam("userId") String userId,
            @PathParam("deviceId") String deviceId) {
        self(userId);
        return service.untrustDevice(userId, deviceId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/overview/{userId}")
    public Uni<IdentityOverviewResponse> overview(@PathParam("userId") String userId) {
        self(userId);
        return service.overview(userId);
    }
}
