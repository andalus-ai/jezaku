package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jActivityCypher.DELETE_ACTIVITIES_FOR_CONTENT;
import static tech.kayys.jezaku.social.Neo4jActivityCypher.READ_ACTIVITIES;
import static tech.kayys.jezaku.social.Neo4jActivityCypher.READ_ACTIVITY;
import static tech.kayys.jezaku.social.Neo4jActivityCypher.SAVE_ACTIVITY;
import static tech.kayys.jezaku.validation.TextParams.requireText;

/**
 * Persists Neo4j social activity and notification graph records.
 */
final class Neo4jActivityGraphStore extends Neo4jGraphStoreSupport implements SocialActivityGraphStore {
    private final Neo4jActivityRecordMapper mapper = new Neo4jActivityRecordMapper();

    Neo4jActivityGraphStore(Neo4jSocialGraphClient client) {
        super(client);
    }

    @Override
    public SocialActivityRecord activity(String activityId) {
        return readOne(READ_ACTIVITY, Map.of("activityId", requireText(activityId, "activityId")),
                mapper::activity);
    }

    @Override
    public List<SocialActivityRecord> activities() {
        return readList(READ_ACTIVITIES, Map.of(), mapper::activity);
    }

    @Override
    public void saveActivity(SocialActivityRecord activity) {
        write(SAVE_ACTIVITY, mapper.activityParameters(activity));
    }

    @Override
    public void removeActivitiesForContent(String contentId) {
        write(DELETE_ACTIVITIES_FOR_CONTENT, Map.of("contentId", requireText(contentId, "contentId")));
    }
}
