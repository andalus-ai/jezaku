package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.Values;
import org.neo4j.driver.internal.InternalRecord;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class Neo4jAdRecordMapperTest {
    private static final Instant STARTS_AT = Instant.parse("2026-06-09T04:00:00Z");
    private static final Instant ENDS_AT = Instant.parse("2026-06-16T04:00:00Z");
    private static final Instant REVIEWED_AT = Instant.parse("2026-06-09T05:00:00Z");
    private static final Instant CREATED_AT = Instant.parse("2026-06-09T03:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-09T06:00:00Z");

    private final Neo4jAdRecordMapper mapper = new Neo4jAdRecordMapper();

    @Test
    void mapsAdCampaignRecordsAndParameters() {
        SocialAdCampaignRecord campaign = mapper.adCampaign(record(campaignFields()));

        assertEquals("campaign_a", campaign.campaignId());
        assertEquals("advertiser_a", campaign.advertiserId());
        assertEquals("brand lift", campaign.name());
        assertEquals("reach", campaign.objective());
        assertEquals("active", campaign.status());
        assertEquals("content_a", campaign.creativeContentId());
        assertEquals("approved", campaign.creativeReviewStatus());
        assertEquals("ok", campaign.creativeReviewReason());
        assertEquals(REVIEWED_AT, campaign.creativeReviewedAt());
        assertEquals("USD", campaign.budgetCurrency());
        assertEquals(500_000L, campaign.budgetCents());
        assertEquals(List.of("friend", "family"), campaign.relationScopes());
        assertEquals(List.of("travel", "food"), campaign.targetTags());
        assertEquals(List.of("group_a"), campaign.targetGroupIds());
        assertEquals(List.of("community_a"), campaign.targetCommunityIds());

        Map<String, Object> parameters = mapper.adCampaignParameters(campaign);

        assertEquals("campaign_a", parameters.get("campaignId"));
        assertEquals("advertiser_a", parameters.get("advertiserId"));
        assertEquals("2026-06-09T05:00:00Z", parameters.get("creativeReviewedAt"));
        assertEquals("2026-06-09T04:00:00Z", parameters.get("startsAt"));
        assertEquals("2026-06-16T04:00:00Z", parameters.get("endsAt"));
        assertEquals(List.of("travel", "food"), parameters.get("targetTags"));
        assertEquals("2026-06-09T06:00:00Z", parameters.get("updatedAt"));
    }

    @Test
    void mapsAdEventRecordsAndParameters() {
        SocialAdEventRecord event = mapper.adEvent(record(eventFields()));

        assertEquals("event_a", event.eventId());
        assertEquals("campaign_a", event.campaignId());
        assertEquals("advertiser_a", event.advertiserId());
        assertEquals("viewer_a", event.viewerId());
        assertEquals("impression", event.eventType());
        assertEquals("feed", event.placement());
        assertEquals("content_a", event.creativeContentId());
        assertEquals(UPDATED_AT, event.occurredAt());
        assertEquals(CREATED_AT, event.createdAt());

        Map<String, Object> parameters = mapper.adEventParameters(event);

        assertEquals("event_a", parameters.get("eventId"));
        assertEquals("campaign_a", parameters.get("campaignId"));
        assertEquals("viewer_a", parameters.get("viewerId"));
        assertEquals("impression", parameters.get("eventType"));
        assertEquals("2026-06-09T06:00:00Z", parameters.get("occurredAt"));
        assertEquals("2026-06-09T03:00:00Z", parameters.get("createdAt"));
    }

    private Map<String, Object> campaignFields() {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("campaignId", "campaign_a");
        fields.put("advertiserId", "advertiser_a");
        fields.put("name", "brand lift");
        fields.put("objective", "reach");
        fields.put("status", "active");
        fields.put("creativeContentId", "content_a");
        fields.put("creativeReviewStatus", "approved");
        fields.put("creativeReviewReason", "ok");
        fields.put("creativeReviewedAt", REVIEWED_AT.toString());
        fields.put("budgetCurrency", "USD");
        fields.put("budgetCents", 500_000L);
        fields.put("startsAt", STARTS_AT.toString());
        fields.put("endsAt", ENDS_AT.toString());
        fields.put("maxDepth", 3);
        fields.put("audienceLimit", 100);
        fields.put("estimatedReach", 42);
        fields.put("relationScopes", List.of("friend", "family"));
        fields.put("targetTags", List.of("travel", "food"));
        fields.put("targetGroupIds", List.of("group_a"));
        fields.put("targetCommunityIds", List.of("community_a"));
        fields.put("createdAt", CREATED_AT.toString());
        fields.put("updatedAt", UPDATED_AT.toString());
        return fields;
    }

    private Map<String, Object> eventFields() {
        Map<String, Object> fields = new LinkedHashMap<>();
        fields.put("eventId", "event_a");
        fields.put("campaignId", "campaign_a");
        fields.put("advertiserId", "advertiser_a");
        fields.put("viewerId", "viewer_a");
        fields.put("eventType", "impression");
        fields.put("placement", "feed");
        fields.put("creativeContentId", "content_a");
        fields.put("occurredAt", UPDATED_AT.toString());
        fields.put("createdAt", CREATED_AT.toString());
        return fields;
    }

    private Record record(Map<String, Object> fields) {
        List<String> keys = new ArrayList<>(fields.keySet());
        List<Value> values = fields.values().stream()
                .map(Values::value)
                .toList();
        return new InternalRecord(keys, values);
    }
}
