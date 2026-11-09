package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class Neo4jRelationshipCypherTest {
    private static final Instant CREATED_AT = Instant.parse("2026-06-09T04:00:00Z");

    @Test
    void selectsMuteStatementByTargetType() {
        assertEquals(
                Neo4jRelationshipCypher.SAVE_USER_MUTE,
                Neo4jRelationshipCypher.muteSaveStatement(mute("user", "user_b")));
        assertEquals(
                Neo4jRelationshipCypher.SAVE_GROUP_MUTE,
                Neo4jRelationshipCypher.muteSaveStatement(mute("group", "group_a")));
        assertEquals(
                Neo4jRelationshipCypher.SAVE_COMMUNITY_MUTE,
                Neo4jRelationshipCypher.muteSaveStatement(mute("community", "community_a")));
    }

    @Test
    void rejectsUnsupportedMuteTargetType() {
        IllegalArgumentException exception = assertThrows(
                IllegalArgumentException.class,
                () -> Neo4jRelationshipCypher.muteSaveStatement(mute("topic", "street-art")));

        assertEquals("Unsupported mute targetType: topic", exception.getMessage());
    }

    private SocialMuteRecord mute(String targetType, String targetId) {
        return new SocialMuteRecord("user_a", targetType, targetId, "", CREATED_AT);
    }
}
