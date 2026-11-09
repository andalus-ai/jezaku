package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialActivityWriteModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-04T16:00:00Z");

    @Test
    void marksSingleActivityReadForRecipientOnly() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveActivity(activity("activity_a", "actor_a", "recipient_a", false));
        SocialActivityWriteModel model = new SocialActivityWriteModel(repository);

        SocialActivityRecord updated = model.markRead("activity_a", "recipient_a");

        assertTrue(updated.read());
        assertTrue(repository.activity("activity_a").read());
        assertThrows(ForbiddenException.class, () -> model.markRead("activity_a", "actor_a"));
        assertThrows(NotFoundException.class, () -> model.markRead("missing_activity", "recipient_a"));
    }

    @Test
    void marksOnlyUnreadInboxActivitiesForUser() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveActivity(activity("inbox_unread_a", "actor_a", "recipient_a", false));
        repository.saveActivity(activity("inbox_unread_b", "actor_b", "recipient_a", false));
        repository.saveActivity(activity("inbox_read", "actor_c", "recipient_a", true));
        repository.saveActivity(activity("outbox_unread", "recipient_a", "other_user", false));
        SocialActivityWriteModel model = new SocialActivityWriteModel(repository);

        SocialActivityWriteModel.MarkReadAllResult result = model.markInboxRead("recipient_a");

        assertEquals("recipient_a", result.userId());
        assertEquals(2, result.markedReadCount());
        assertEquals(0, result.unreadCount());
        assertTrue(repository.activity("inbox_unread_a").read());
        assertTrue(repository.activity("inbox_unread_b").read());
        assertTrue(repository.activity("inbox_read").read());
        assertEquals(false, repository.activity("outbox_unread").read());
    }

    @Test
    void bulkMarkReadIsIdempotent() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveActivity(activity("activity_a", "actor_a", "recipient_a", false));
        SocialActivityWriteModel model = new SocialActivityWriteModel(repository);

        SocialActivityWriteModel.MarkReadAllResult first = model.markInboxRead("recipient_a");
        SocialActivityWriteModel.MarkReadAllResult second = model.markInboxRead("recipient_a");

        assertEquals(1, first.markedReadCount());
        assertEquals(0, second.markedReadCount());
        assertTrue(repository.activity("activity_a").read());
    }

    private static SocialActivityRecord activity(
            String activityId,
            String actorId,
            String recipientId,
            boolean read) {
        return new SocialActivityRecord(
                activityId,
                "content_liked",
                actorId,
                recipientId,
                "content_a",
                "",
                "like",
                "message",
                BASE_TIME,
                read);
    }
}
