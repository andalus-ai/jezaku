package tech.kayys.jezaku.events;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.events.EventDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class InMemoryEventRepositoryTest {
    @Test
    void savesFindsAndListsEventRecords() {
        InMemoryEventRepository repository = new InMemoryEventRepository();
        Instant now = Instant.parse("2026-05-30T00:00:00Z");
        EventRecord event = new EventRecord(
                "event_repo",
                "organizer_repo",
                "Repository Meetup",
                "Repository backed event.",
                "meetup",
                "public",
                "place_repo",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                50.0,
                now.plusSeconds(3_600),
                now.plusSeconds(7_200),
                20,
                List.of("repo"),
                List.of("anchor_repo"),
                "scheduled",
                now,
                now);
        RsvpRecord rsvp = new RsvpRecord("event_repo", "guest_repo", "going", now);
        CheckInRecord checkIn = new CheckInRecord("event_repo", "guest_repo", 1.25, now);
        InviteRecord invite = new InviteRecord(
                "invite_repo",
                "event_repo",
                "organizer_repo",
                "guest_repo",
                "Join us.",
                "pending",
                now,
                now);
        EventActivityEvent activity = new EventActivityEvent(
                "activity_repo",
                "event_repo",
                "organizer_repo",
                "invite",
                "guest_repo",
                "Join us.",
                now);

        repository.saveEvent(event);
        repository.saveRsvp(rsvp);
        repository.saveCheckIn(checkIn);
        repository.saveInvite(invite);
        repository.saveActivity(activity);

        assertEquals(event, repository.findEventById("event_repo"));
        assertEquals(List.of(event), repository.findAllEvents());
        assertEquals(rsvp, repository.findRsvp("event_repo", "guest_repo"));
        assertEquals(List.of(rsvp), repository.findAllRsvps());
        assertEquals(List.of(checkIn), repository.findAllCheckIns());
        assertEquals(invite, repository.findInvite("event_repo", "guest_repo"));
        assertEquals(List.of(invite), repository.findAllInvites());
        assertEquals(List.of(activity), repository.findActivityByEventId("event_repo"));
    }
}
