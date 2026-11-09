package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class Neo4jCircleCypherTest {
    private static final Instant CREATED_AT = Instant.parse("2026-06-09T04:00:00Z");
    private static final Instant UPDATED_AT = Instant.parse("2026-06-09T04:30:00Z");

    @Test
    void selectsMembershipRequestStatementByTargetAndRequestType() {
        assertEquals(
                Neo4jCircleCypher.SAVE_GROUP_JOIN_REQUEST,
                Neo4jCircleCypher.circleMembershipRequestSaveStatement(request("group", "join_request")));
        assertEquals(
                Neo4jCircleCypher.SAVE_COMMUNITY_JOIN_REQUEST,
                Neo4jCircleCypher.circleMembershipRequestSaveStatement(request("community", "join_request")));
        assertEquals(
                Neo4jCircleCypher.SAVE_GROUP_INVITE,
                Neo4jCircleCypher.circleMembershipRequestSaveStatement(request("group", "invite")));
        assertEquals(
                Neo4jCircleCypher.SAVE_COMMUNITY_INVITE,
                Neo4jCircleCypher.circleMembershipRequestSaveStatement(request("community", "invite")));
    }

    @Test
    void rejectsUnsupportedMembershipRequestTargetAndType() {
        IllegalArgumentException exception = assertThrows(
                IllegalArgumentException.class,
                () -> Neo4jCircleCypher.circleMembershipRequestSaveStatement(request("topic", "join_request")));

        assertEquals("Unsupported circle membership request target/request type: topic/join_request",
                exception.getMessage());
    }

    private CircleMembershipRequestRecord request(String targetType, String requestType) {
        return new CircleMembershipRequestRecord(
                "request_a",
                "target_a",
                targetType,
                "user_a",
                "owner_a",
                requestType,
                "pending",
                "",
                CREATED_AT,
                UPDATED_AT);
    }
}
