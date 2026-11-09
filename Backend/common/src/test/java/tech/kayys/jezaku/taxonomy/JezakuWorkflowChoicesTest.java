package tech.kayys.jezaku.taxonomy;

import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JezakuWorkflowChoicesTest {
    @Test
    void exposesWorkflowChoiceSets() {
        assertEquals(Set.of("active", "suspended", "deleted"), JezakuWorkflowChoices.ACCOUNT_STATUSES);
        assertEquals(Set.of("pending", "approved", "rejected"), JezakuWorkflowChoices.MEDIA_MODERATION_STATUSES);
        assertEquals(Set.of("info", "warning", "critical"), JezakuWorkflowChoices.NOTIFICATION_SEVERITIES);
        assertEquals(Set.of("in_app", "push", "email"), JezakuWorkflowChoices.NOTIFICATION_CHANNELS);
        assertEquals(Set.of("going", "interested", "declined"), JezakuWorkflowChoices.EVENT_RSVP_STATUSES);
        assertEquals(Set.of("open", "reviewing", "resolved", "dismissed"),
                JezakuWorkflowChoices.SAFETY_REPORT_STATUSES);
        assertEquals(Set.of("none", "hide_content", "warn_user", "suspend_user", "notify_guardian"),
                JezakuWorkflowChoices.SAFETY_REVIEW_ACTIONS);
        assertEquals(Set.of("safe_area", "restricted_area", "quiet_area"), JezakuWorkflowChoices.SAFETY_ZONE_TYPES);
        assertThrows(UnsupportedOperationException.class,
                () -> JezakuWorkflowChoices.ACCOUNT_STATUSES.add("pending"));
    }
}
