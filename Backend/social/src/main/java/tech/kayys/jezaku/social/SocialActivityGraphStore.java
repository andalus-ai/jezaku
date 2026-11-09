package tech.kayys.jezaku.social;

import java.util.List;

/**
 * Persists social activity records used by notification and inbox projections.
 */
interface SocialActivityGraphStore {
    SocialActivityRecord activity(String activityId);

    List<SocialActivityRecord> activities();

    void saveActivity(SocialActivityRecord activity);

    void removeActivitiesForContent(String contentId);
}
