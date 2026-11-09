package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class Neo4jSocialGraphRepositoryTest {
    @Test
    void parsesBundledSchemaBootstrapStatements() {
        List<String> statements = Neo4jSocialGraphRepository.schemaStatements();

        assertEquals(30, statements.size());
        assertTrue(statements.getFirst().startsWith("CREATE CONSTRAINT jezaku_user_id"));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_user_handle")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_content_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_comment_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_activity_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_topic_tag")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("FRIEND_REQUEST")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("FOLLOW_REQUESTED")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_user_follow_request")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("JOIN_REQUESTED")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("INVITED_TO")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("MODERATED_CONTENT")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("MUTED")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_mute_target")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_share_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_content_report_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_mention_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_content_owner_scope")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_comment_content")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_comment_parent")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_activity_recipient")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_activity_actor")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_campaign_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_campaign_advertiser")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_campaign_status")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_campaign_creative_review")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_event_id")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_event_campaign")));
        assertTrue(statements.stream().anyMatch(statement -> statement.contains("jezaku_ad_event_viewer")));
        assertFalse(statements.stream().anyMatch(statement -> statement.contains("//")));
        assertFalse(statements.stream().anyMatch(statement -> statement.endsWith(";")));
    }
}
