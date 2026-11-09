package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

class Neo4jAdCypherTest {
    @Test
    void campaignStatementsPreserveAdvertiserOwnershipGraphShape() {
        assertTrue(Neo4jAdCypher.READ_AD_CAMPAIGNS.contains("ORDER BY campaign.createdAt DESC"));
        assertTrue(Neo4jAdCypher.SAVE_AD_CAMPAIGN.contains("ADVERTISER_OF"));
    }

    @Test
    void eventStatementsPreserveCampaignViewerAndAdvertiserGraphShape() {
        assertTrue(Neo4jAdCypher.READ_AD_EVENTS.contains("ORDER BY event.occurredAt DESC"));
        assertTrue(Neo4jAdCypher.SAVE_AD_EVENT.contains("EMITTED_AD_EVENT"));
        assertTrue(Neo4jAdCypher.SAVE_AD_EVENT.contains("AD_EVENT_VIEWER"));
        assertTrue(Neo4jAdCypher.SAVE_AD_EVENT.contains("AD_EVENT_ADVERTISER"));
    }
}
