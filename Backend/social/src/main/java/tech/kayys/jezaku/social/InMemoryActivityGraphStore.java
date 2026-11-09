package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Stores social activity and notification records in memory for tests and local fallback mode.
 */
final class InMemoryActivityGraphStore implements SocialActivityGraphStore {
    private final Map<String, SocialActivityRecord> activities = new ConcurrentHashMap<>();

    @Override
    public SocialActivityRecord activity(String activityId) {
        return activities.get(requireText(activityId, "activityId"));
    }

    @Override
    public List<SocialActivityRecord> activities() {
        return List.copyOf(activities.values());
    }

    @Override
    public void saveActivity(SocialActivityRecord activity) {
        activities.put(requireText(activity.activityId(), "activityId"), activity);
    }

    @Override
    public void removeActivitiesForContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        activities.values().removeIf(activity -> activity.contentId().equals(normalizedContentId));
    }

    void clear() {
        activities.clear();
    }
}
