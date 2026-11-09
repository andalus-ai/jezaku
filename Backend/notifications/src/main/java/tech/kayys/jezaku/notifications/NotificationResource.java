package tech.kayys.jezaku.notifications;

import io.smallrye.mutiny.Uni;
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
import tech.kayys.jezaku.notifications.NotificationDtos.DeviceRegistrationRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.DeviceRegistrationResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.MarkReadRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.MessagingNotificationHandoffRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationCreateRequest;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationDeliveryHistoryResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationInboxResponse;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationPreferences;
import tech.kayys.jezaku.notifications.NotificationDtos.NotificationResponse;

import java.util.List;

@Path("/notifications")
@Produces(MediaType.APPLICATION_JSON)
public class NotificationResource {
    @Inject
    NotificationService service;

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> create(NotificationCreateRequest request) {
        return service.create(request)
                .map(created -> Response.status(Response.Status.CREATED).entity(created).build());
    }

    @POST
    @Path("/intake/messaging")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<Response> ingestMessaging(MessagingNotificationHandoffRequest request) {
        return service.ingestMessagingHandoff(request)
                .map(response -> Response.status(response.duplicate()
                        ? Response.Status.OK
                        : Response.Status.CREATED).entity(response).build());
    }

    @GET
    @Path("/users/{userId}")
    public Uni<NotificationInboxResponse> inbox(
            @PathParam("userId") String userId,
            @QueryParam("unreadOnly") Boolean unreadOnly,
            @QueryParam("limit") Integer limit) {
        return service.inbox(userId, unreadOnly, limit);
    }

    @POST
    @Path("/users/{userId}/read")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<NotificationInboxResponse> markRead(
            @PathParam("userId") String userId,
            MarkReadRequest request) {
        return service.markRead(userId, request);
    }

    @GET
    @Path("/users/{userId}/{notificationId}/delivery")
    public Uni<NotificationDeliveryHistoryResponse> deliveryHistory(
            @PathParam("userId") String userId,
            @PathParam("notificationId") String notificationId) {
        return service.deliveryHistory(userId, notificationId);
    }

    @DELETE
    @Path("/users/{userId}/{notificationId}")
    public Uni<Response> delete(
            @PathParam("userId") String userId,
            @PathParam("notificationId") String notificationId) {
        return service.delete(userId, notificationId)
                .replaceWith(Response.noContent().build());
    }

    @GET
    @Path("/users/{userId}/preferences")
    public Uni<NotificationPreferences> preferences(@PathParam("userId") String userId) {
        return service.preferences(userId);
    }

    @PUT
    @Path("/users/{userId}/preferences")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<NotificationPreferences> updatePreferences(
            @PathParam("userId") String userId,
            NotificationPreferences request) {
        return service.updatePreferences(userId, request);
    }

    @POST
    @Path("/devices")
    @Consumes(MediaType.APPLICATION_JSON)
    public Uni<DeviceRegistrationResponse> registerDevice(DeviceRegistrationRequest request) {
        return service.registerDevice(request);
    }

    @GET
    @Path("/devices/{userId}")
    public Uni<List<DeviceRegistrationResponse>> devices(@PathParam("userId") String userId) {
        return service.devices(userId);
    }

    @DELETE
    @Path("/devices/{userId}/{deviceId}")
    public Uni<Response> disableDevice(
            @PathParam("userId") String userId,
            @PathParam("deviceId") String deviceId) {
        return service.disableDevice(userId, deviceId)
                .replaceWith(Response.noContent().build());
    }
}
