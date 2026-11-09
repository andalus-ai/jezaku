package tech.kayys.jezaku.social;

/**
 * Defines Neo4j Cypher statements for ad campaign and ad event monetization graph records.
 */
final class Neo4jAdCypher {
    static final String READ_AD_CAMPAIGN = """
            MATCH (campaign:AdCampaign {campaignId: $campaignId})
            RETURN campaign.campaignId AS campaignId,
                   campaign.advertiserId AS advertiserId,
                   campaign.name AS name,
                   campaign.objective AS objective,
                   campaign.status AS status,
                   coalesce(campaign.creativeContentId, '') AS creativeContentId,
                   coalesce(campaign.creativeReviewStatus, 'pending_review') AS creativeReviewStatus,
                   coalesce(campaign.creativeReviewReason, '') AS creativeReviewReason,
                   campaign.creativeReviewedAt AS creativeReviewedAt,
                   campaign.budgetCurrency AS budgetCurrency,
                   campaign.budgetCents AS budgetCents,
                   campaign.startsAt AS startsAt,
                   campaign.endsAt AS endsAt,
                   campaign.maxDepth AS maxDepth,
                   campaign.audienceLimit AS audienceLimit,
                   campaign.estimatedReach AS estimatedReach,
                   coalesce(campaign.relationScopes, []) AS relationScopes,
                   coalesce(campaign.targetTags, []) AS targetTags,
                   coalesce(campaign.targetGroupIds, []) AS targetGroupIds,
                   coalesce(campaign.targetCommunityIds, []) AS targetCommunityIds,
                   campaign.createdAt AS createdAt,
                   campaign.updatedAt AS updatedAt
            """;
    static final String READ_AD_CAMPAIGNS = """
            MATCH (campaign:AdCampaign)
            RETURN campaign.campaignId AS campaignId,
                   campaign.advertiserId AS advertiserId,
                   campaign.name AS name,
                   campaign.objective AS objective,
                   campaign.status AS status,
                   coalesce(campaign.creativeContentId, '') AS creativeContentId,
                   coalesce(campaign.creativeReviewStatus, 'pending_review') AS creativeReviewStatus,
                   coalesce(campaign.creativeReviewReason, '') AS creativeReviewReason,
                   campaign.creativeReviewedAt AS creativeReviewedAt,
                   campaign.budgetCurrency AS budgetCurrency,
                   campaign.budgetCents AS budgetCents,
                   campaign.startsAt AS startsAt,
                   campaign.endsAt AS endsAt,
                   campaign.maxDepth AS maxDepth,
                   campaign.audienceLimit AS audienceLimit,
                   campaign.estimatedReach AS estimatedReach,
                   coalesce(campaign.relationScopes, []) AS relationScopes,
                   coalesce(campaign.targetTags, []) AS targetTags,
                   coalesce(campaign.targetGroupIds, []) AS targetGroupIds,
                   coalesce(campaign.targetCommunityIds, []) AS targetCommunityIds,
                   campaign.createdAt AS createdAt,
                   campaign.updatedAt AS updatedAt
            ORDER BY campaign.createdAt DESC, campaign.campaignId
            """;
    static final String SAVE_AD_CAMPAIGN = """
            MERGE (advertiser:User {userId: $advertiserId})
            MERGE (campaign:AdCampaign {campaignId: $campaignId})
            SET campaign.advertiserId = $advertiserId,
                campaign.name = $name,
                campaign.objective = $objective,
                campaign.status = $status,
                campaign.creativeContentId = $creativeContentId,
                campaign.creativeReviewStatus = $creativeReviewStatus,
                campaign.creativeReviewReason = $creativeReviewReason,
                campaign.creativeReviewedAt = $creativeReviewedAt,
                campaign.budgetCurrency = $budgetCurrency,
                campaign.budgetCents = $budgetCents,
                campaign.startsAt = $startsAt,
                campaign.endsAt = $endsAt,
                campaign.maxDepth = $maxDepth,
                campaign.audienceLimit = $audienceLimit,
                campaign.estimatedReach = $estimatedReach,
                campaign.relationScopes = $relationScopes,
                campaign.targetTags = $targetTags,
                campaign.targetGroupIds = $targetGroupIds,
                campaign.targetCommunityIds = $targetCommunityIds,
                campaign.createdAt = $createdAt,
                campaign.updatedAt = $updatedAt
            MERGE (advertiser)-[owns:ADVERTISER_OF]->(campaign)
            SET owns.createdAt = $createdAt
            """;
    static final String READ_AD_EVENT = """
            MATCH (event:AdEvent {eventId: $eventId})
            RETURN event.eventId AS eventId,
                   event.campaignId AS campaignId,
                   event.advertiserId AS advertiserId,
                   event.viewerId AS viewerId,
                   event.eventType AS eventType,
                   event.placement AS placement,
                   coalesce(event.creativeContentId, '') AS creativeContentId,
                   event.occurredAt AS occurredAt,
                   event.createdAt AS createdAt
            """;
    static final String READ_AD_EVENTS = """
            MATCH (event:AdEvent)
            RETURN event.eventId AS eventId,
                   event.campaignId AS campaignId,
                   event.advertiserId AS advertiserId,
                   event.viewerId AS viewerId,
                   event.eventType AS eventType,
                   event.placement AS placement,
                   coalesce(event.creativeContentId, '') AS creativeContentId,
                   event.occurredAt AS occurredAt,
                   event.createdAt AS createdAt
            ORDER BY event.occurredAt DESC, event.eventId
            """;
    static final String SAVE_AD_EVENT = """
            MERGE (campaign:AdCampaign {campaignId: $campaignId})
            MERGE (viewer:User {userId: $viewerId})
            MERGE (advertiser:User {userId: $advertiserId})
            MERGE (event:AdEvent {eventId: $eventId})
            SET event.campaignId = $campaignId,
                event.advertiserId = $advertiserId,
                event.viewerId = $viewerId,
                event.eventType = $eventType,
                event.placement = $placement,
                event.creativeContentId = $creativeContentId,
                event.occurredAt = $occurredAt,
                event.createdAt = $createdAt
            MERGE (campaign)-[emitted:EMITTED_AD_EVENT]->(event)
            SET emitted.createdAt = $createdAt
            MERGE (viewer)-[viewed:AD_EVENT_VIEWER]->(event)
            SET viewed.createdAt = $createdAt
            MERGE (advertiser)-[attributed:AD_EVENT_ADVERTISER]->(event)
            SET attributed.createdAt = $createdAt
            """;

    private Neo4jAdCypher() {
    }
}
