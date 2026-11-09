package tech.kayys.jezaku.spatial;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.spatial.AnchorConfidencePolicy.AnchorConfidence;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AnchorConfidencePolicyTest {
    @Test
    void scoresHighConfidenceHybridAnchor() {
        AnchorConfidence confidence = AnchorConfidencePolicy.evaluate(
                "hybrid",
                true,
                5.0,
                345.0,
                -12.5,
                1.25,
                3.2);

        assertEquals("high", confidence.level());
        assertEquals(100, confidence.score());
        assertTrue(confidence.reasons().contains("anchor_type_hybrid"));
        assertTrue(confidence.reasons().contains("gps_accuracy_high"));
        assertTrue(confidence.reasons().contains("orientation_heading_and_compass"));
        assertTrue(confidence.reasons().contains("altitude_present"));
        assertTrue(confidence.recommendedActions().isEmpty());
    }

    @Test
    void scoresMediumAnchorWhenGpsAndOrientationAreUsableButAltitudeIsMissing() {
        AnchorConfidence confidence = AnchorConfidencePolicy.evaluate(
                "geo",
                false,
                null,
                91.0,
                null,
                null,
                8.0);

        assertEquals("medium", confidence.level());
        assertTrue(confidence.score() >= 60);
        assertTrue(confidence.score() < 80);
        assertTrue(confidence.reasons().contains("gps_accuracy_medium"));
        assertTrue(confidence.reasons().contains("orientation_partial"));
        assertTrue(confidence.recommendedActions().contains("enable_altitude"));
        assertTrue(confidence.recommendedActions().contains("stabilize_camera_pose"));
    }

    @Test
    void capsLowAnchorWhenGpsAccuracyIsTooWeakForArPlacement() {
        AnchorConfidence confidence = AnchorConfidencePolicy.evaluate(
                "visual",
                true,
                12.0,
                12.0,
                -4.0,
                1.0,
                25.0);

        assertEquals("low", confidence.level());
        assertTrue(confidence.score() < 60);
        assertTrue(confidence.reasons().contains("gps_accuracy_low"));
        assertTrue(confidence.recommendedActions().contains("recapture_with_better_gps"));
    }

    @Test
    void explainsMissingSensorData() {
        AnchorConfidence confidence = AnchorConfidencePolicy.evaluate(
                "geo",
                false,
                null,
                null,
                null,
                null,
                null);

        assertEquals("low", confidence.level());
        assertTrue(confidence.score() < 60);
        assertTrue(confidence.reasons().contains("gps_accuracy_missing"));
        assertTrue(confidence.reasons().contains("orientation_missing"));
        assertTrue(confidence.recommendedActions().contains("recapture_with_better_gps"));
        assertTrue(confidence.recommendedActions().contains("calibrate_compass"));
        assertTrue(confidence.recommendedActions().contains("enable_altitude"));
        assertTrue(confidence.recommendedActions().contains("stabilize_camera_pose"));
    }
}
