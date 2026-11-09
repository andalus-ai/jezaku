package tech.kayys.jezaku.events;

import java.util.List;

interface EventRepository {
    void saveEvent(EventRecord event);

    EventRecord findEventById(String eventId);

    List<EventRecord> findAllEvents();

    void saveRsvp(RsvpRecord rsvp);

    RsvpRecord findRsvp(String eventId, String userId);

    List<RsvpRecord> findAllRsvps();

    void saveCheckIn(CheckInRecord checkIn);

    List<CheckInRecord> findAllCheckIns();

    void saveInvite(InviteRecord invite);

    InviteRecord findInvite(String eventId, String inviteeUserId);

    List<InviteRecord> findAllInvites();

    void saveActivity(EventActivityEvent activity);

    List<EventActivityEvent> findActivityByEventId(String eventId);
}
