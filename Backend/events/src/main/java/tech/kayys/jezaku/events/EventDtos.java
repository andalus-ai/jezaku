package tech.kayys.jezaku.events;

import java.time.Instant;
import java.util.List;

public final class EventDtos {
    private EventDtos() {
    }

    public record GeoPoint(double latitude, double longitude, Double altitudeMeters) {
    }

    public record EventCreateRequest(
            String organizerId,
            String title,
            String description,
            String category,
            String visibility,
            String placeId,
            GeoPoint center,
            Double checkInRadiusMeters,
            Instant startsAt,
            Instant endsAt,
            Integer capacity,
            List<String> tags,
            List<String> anchorIds) {
    }

    public record EventResponse(
            String id,
            String organizerId,
            String title,
            String description,
            String category,
            String visibility,
            String placeId,
            GeoPoint center,
            double checkInRadiusMeters,
            Instant startsAt,
            Instant endsAt,
            int capacity,
            List<String> tags,
            List<String> anchorIds,
            String status,
            int goingCount,
            int interestedCount,
            int checkedInCount,
            int invitationCount,
            double distanceMeters,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record EventFeedResponse(String userId, int count, List<EventResponse> events) {
    }

    public record EventActivityResponse(
            String activityId,
            String eventId,
            String actorUserId,
            String activityType,
            String targetUserId,
            String detail,
            Instant createdAt) {
    }

    public record EventActivityHistoryResponse(String eventId, int count, List<EventActivityResponse> activity) {
    }

    public record RsvpRequest(String userId, String status) {
    }

    public record RsvpResponse(String eventId, String userId, String status, Instant updatedAt) {
    }

    public record CheckInRequest(String userId, GeoPoint position) {
    }

    public record CheckInResponse(
            String eventId,
            String userId,
            boolean checkedIn,
            double distanceMeters,
            Instant checkedInAt) {
    }

    public record InviteRequest(String inviterId, List<String> inviteeUserIds, String message) {
    }

    public record InviteResponse(
            String id,
            String eventId,
            String inviterId,
            String inviteeUserId,
            String message,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }
}
