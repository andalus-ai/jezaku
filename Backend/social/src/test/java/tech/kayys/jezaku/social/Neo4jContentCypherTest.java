package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

class Neo4jContentCypherTest {
    @Test
    void contentLifecycleStatementsPreserveOwnershipGraphShape() {
        assertTrue(Neo4jContentCypher.SAVE_CONTENT.contains("CREATED"));
        assertTrue(Neo4jContentCypher.DELETE_CONTENT.contains("DETACH DELETE"));
    }

    @Test
    void engagementStatementsPreserveInteractionGraphShape() {
        assertTrue(Neo4jEngagementCypher.SAVE_COMMENT.contains("REPLIED_TO"));
        assertTrue(Neo4jEngagementCypher.SAVE_COMMENT_REACTION.contains("REACTED_TO_COMMENT"));
        assertTrue(Neo4jEngagementCypher.SAVE_SAVE.contains("SAVED"));
        assertTrue(Neo4jEngagementCypher.SAVE_SHARE.contains("SHARED"));
    }

    @Test
    void tagAndSafetyStatementsPreserveDiscoveryAndModerationGraphShape() {
        assertTrue(Neo4jTagCypher.SAVE_CONTENT_TAG.contains("TAGGED_WITH"));
        assertTrue(Neo4jTagCypher.SAVE_TAG_FOLLOW.contains("FOLLOWS_TOPIC"));
        assertTrue(Neo4jContentSafetyCypher.SAVE_CONTENT_HIDE.contains("HIDDEN_CONTENT"));
        assertTrue(Neo4jContentSafetyCypher.SAVE_CONTENT_REPORT.contains("REPORTED"));
    }

    @Test
    void mentionAndActivityStatementsPreserveNotificationGraphShape() {
        assertTrue(Neo4jMentionCypher.SAVE_MENTION.contains("MENTIONS"));
        assertTrue(Neo4jMentionCypher.DELETE_MENTIONS_FOR_CONTENT_SOURCE.contains("sourceType"));
        assertTrue(Neo4jActivityCypher.SAVE_ACTIVITY.contains("PERFORMED"));
        assertTrue(Neo4jActivityCypher.SAVE_ACTIVITY.contains("DELIVERED_TO"));
    }
}
