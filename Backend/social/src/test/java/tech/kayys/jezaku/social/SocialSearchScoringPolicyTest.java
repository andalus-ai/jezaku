package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.VisibilityDecision;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialSearchScoringPolicyTest {
    private final SocialSearchScoringPolicy policy = new SocialSearchScoringPolicy();

    @Test
    void scoresTextMatchesByStrength() {
        assertEquals(100.0, policy.textMatchScore("city", "city"), 0.0001);
        assertEquals(80.0, policy.textMatchScore("city", "city walk"), 0.0001);
        assertEquals(65.0, policy.textMatchScore("city", "walk city"), 0.0001);
        assertEquals(50.0, policy.textMatchScore("ity", "city"), 0.0001);
        assertEquals(0.0, policy.textMatchScore("city", "", null, "walk"), 0.0001);
        assertTrue(policy.matches("city", "CITY WALK"));
        assertFalse(policy.matches("city", "forest"));
    }

    @Test
    void capsSocialSignalsForSearchResultTypes() {
        assertEquals(62.0, policy.userScore(10.0, relationshipContext(200.0), 99, 99), 0.0001);
        assertEquals(97.0, policy.circleScore(50.0, true, 99, 99), 0.0001);
        assertEquals(95.0, policy.tagScore(65.0, 99, 99), 0.0001);
    }

    private SocialRelationshipContextResponse relationshipContext(double affinityScore) {
        return new SocialRelationshipContextResponse(
                "viewer",
                "owner",
                "friend",
                1,
                affinityScore,
                false,
                true,
                false,
                false,
                false,
                "",
                "",
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                new VisibilityDecision(
                        "viewer",
                        "owner",
                        "friend",
                        true,
                        true,
                        true,
                        true,
                        "friend"));
    }
}
