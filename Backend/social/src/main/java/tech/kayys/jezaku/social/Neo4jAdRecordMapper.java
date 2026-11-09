package tech.kayys.jezaku.social;

import org.neo4j.driver.Record;

import java.util.HashMap;
import java.util.Map;

import static tech.kayys.jezaku.social.Neo4jRecordValues.instant;
import static tech.kayys.jezaku.social.Neo4jRecordValues.iso;
import static tech.kayys.jezaku.social.Neo4jRecordValues.nullableInstant;
import static tech.kayys.jezaku.social.Neo4jRecordValues.stringList;

/**
 * Maps Neo4j monetization rows into ad campaign and ad event graph records.
 */
final class Neo4jAdRecordMapper {
    SocialAdCampaignRecord adCampaign(Record record) {
        return new SocialAdCampaignRecord(
                record.get("campaignId").asString(),
                record.get("advertiserId").asString(),
                record.get("name").asString(),
                record.get("objective").asString(),
                record.get("status").asString(),
                record.get("creativeContentId").asString(),
                record.get("creativeReviewStatus").asString("pending_review"),
                record.get("creativeReviewReason").asString(""),
                nullableInstant(record, "creativeReviewedAt"),
                record.get("budgetCurrency").asString(),
                record.get("budgetCents").asLong(),
                instant(record, "startsAt"),
                instant(record, "endsAt"),
                record.get("maxDepth").asInt(),
                record.get("audienceLimit").asInt(),
                record.get("estimatedReach").asInt(),
                stringList(record, "relationScopes"),
                stringList(record, "targetTags"),
                stringList(record, "targetGroupIds"),
                stringList(record, "targetCommunityIds"),
                instant(record, "createdAt"),
                instant(record, "updatedAt"));
    }

    Map<String, Object> adCampaignParameters(SocialAdCampaignRecord campaign) {
        Map<String, Object> parameters = new HashMap<>();
        parameters.put("campaignId", campaign.campaignId());
        parameters.put("advertiserId", campaign.advertiserId());
        parameters.put("name", campaign.name());
        parameters.put("objective", campaign.objective());
        parameters.put("status", campaign.status());
        parameters.put("creativeContentId", campaign.creativeContentId());
        parameters.put("creativeReviewStatus", campaign.creativeReviewStatus());
        parameters.put("creativeReviewReason", campaign.creativeReviewReason());
        parameters.put(
                "creativeReviewedAt",
                campaign.creativeReviewedAt() == null ? null : iso(campaign.creativeReviewedAt()));
        parameters.put("budgetCurrency", campaign.budgetCurrency());
        parameters.put("budgetCents", campaign.budgetCents());
        parameters.put("startsAt", iso(campaign.startsAt()));
        parameters.put("endsAt", iso(campaign.endsAt()));
        parameters.put("maxDepth", campaign.maxDepth());
        parameters.put("audienceLimit", campaign.audienceLimit());
        parameters.put("estimatedReach", campaign.estimatedReach());
        parameters.put("relationScopes", campaign.relationScopes());
        parameters.put("targetTags", campaign.targetTags());
        parameters.put("targetGroupIds", campaign.targetGroupIds());
        parameters.put("targetCommunityIds", campaign.targetCommunityIds());
        parameters.put("createdAt", iso(campaign.createdAt()));
        parameters.put("updatedAt", iso(campaign.updatedAt()));
        return parameters;
    }

    SocialAdEventRecord adEvent(Record record) {
        return new SocialAdEventRecord(
                record.get("eventId").asString(),
                record.get("campaignId").asString(),
                record.get("advertiserId").asString(),
                record.get("viewerId").asString(),
                record.get("eventType").asString(),
                record.get("placement").asString(),
                record.get("creativeContentId").asString(),
                instant(record, "occurredAt"),
                instant(record, "createdAt"));
    }

    Map<String, Object> adEventParameters(SocialAdEventRecord event) {
        Map<String, Object> parameters = new HashMap<>();
        parameters.put("eventId", event.eventId());
        parameters.put("campaignId", event.campaignId());
        parameters.put("advertiserId", event.advertiserId());
        parameters.put("viewerId", event.viewerId());
        parameters.put("eventType", event.eventType());
        parameters.put("placement", event.placement());
        parameters.put("creativeContentId", event.creativeContentId());
        parameters.put("occurredAt", iso(event.occurredAt()));
        parameters.put("createdAt", iso(event.createdAt()));
        return parameters;
    }
}
