package tech.kayys.jezaku.taxonomy;

import java.util.Set;

public final class JezakuWorkflowChoices {
    public static final Set<String> ACCOUNT_STATUSES = Set.of("active", "suspended", "deleted");
    public static final Set<String> MEDIA_MODERATION_STATUSES = Set.of("pending", "approved", "rejected");
    public static final Set<String> NOTIFICATION_SEVERITIES = Set.of("info", "warning", "critical");
    public static final Set<String> NOTIFICATION_CHANNELS = Set.of("in_app", "push", "email");
    public static final Set<String> EVENT_RSVP_STATUSES = Set.of("going", "interested", "declined");
    public static final Set<String> SAFETY_REPORT_STATUSES = Set.of("open", "reviewing", "resolved", "dismissed");
    public static final Set<String> SAFETY_REVIEW_ACTIONS = Set.of(
            "none",
            "hide_content",
            "warn_user",
            "suspend_user",
            "notify_guardian");
    public static final Set<String> SAFETY_ZONE_TYPES = Set.of("safe_area", "restricted_area", "quiet_area");

    private JezakuWorkflowChoices() {
    }
}
