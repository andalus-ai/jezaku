package tech.kayys.jezaku.events;

import jakarta.enterprise.context.ApplicationScoped;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class InMemoryEventRepository implements EventRepository {
    private final Map<String, EventRecord> events = new ConcurrentHashMap<>();
    private final Map<String, RsvpRecord> rsvps = new ConcurrentHashMap<>();
    private final Map<String, CheckInRecord> checkIns = new ConcurrentHashMap<>();
    private final Map<String, InviteRecord> invites = new ConcurrentHashMap<>();
    private final Map<String, List<EventActivityEvent>> activity = new ConcurrentHashMap<>();

    @Override
    public void saveEvent(EventRecord event) {
        events.put(event.id(), event);
    }

    @Override
    public EventRecord findEventById(String eventId) {
        return events.get(eventId);
    }

    @Override
    public List<EventRecord> findAllEvents() {
        return List.copyOf(events.values());
    }

    @Override
    public void saveRsvp(RsvpRecord rsvp) {
        rsvps.put(participantKey(rsvp.eventId(), rsvp.userId()), rsvp);
    }

    @Override
    public RsvpRecord findRsvp(String eventId, String userId) {
        return rsvps.get(participantKey(eventId, userId));
    }

    @Override
    public List<RsvpRecord> findAllRsvps() {
        return List.copyOf(rsvps.values());
    }

    @Override
    public void saveCheckIn(CheckInRecord checkIn) {
        checkIns.put(participantKey(checkIn.eventId(), checkIn.userId()), checkIn);
    }

    @Override
    public List<CheckInRecord> findAllCheckIns() {
        return List.copyOf(checkIns.values());
    }

    @Override
    public void saveInvite(InviteRecord invite) {
        invites.put(participantKey(invite.eventId(), invite.inviteeUserId()), invite);
    }

    @Override
    public InviteRecord findInvite(String eventId, String inviteeUserId) {
        return invites.get(participantKey(eventId, inviteeUserId));
    }

    @Override
    public List<InviteRecord> findAllInvites() {
        return List.copyOf(invites.values());
    }

    @Override
    public void saveActivity(EventActivityEvent event) {
        activity.compute(event.eventId(), (eventId, events) -> {
            List<EventActivityEvent> updated = new ArrayList<>();
            if (events != null) {
                updated.addAll(events);
            }
            updated.add(event);
            return List.copyOf(updated);
        });
    }

    @Override
    public List<EventActivityEvent> findActivityByEventId(String eventId) {
        return List.copyOf(activity.getOrDefault(eventId, List.of()));
    }

    private String participantKey(String eventId, String userId) {
        return eventId + "->" + userId;
    }
}
