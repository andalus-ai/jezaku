package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraTelemetryQualityPolicyTest {
    @Test
    void scoresHighQualityTelemetryForStableAccurateSensors() {
        var quality = CameraTelemetryQualityPolicy.evaluate(
                6.0,
                4.0,
                12.0,
                8.0,
                1.2,
                "walking");

        assertEquals(100, quality.score());
        assertEquals("high", quality.level());
        assertEquals("walking", quality.motionState());
        assertTrue(quality.reasons().contains("gps_accuracy_high"));
        assertTrue(quality.reasons().contains("altitude_accuracy_high"));
        assertTrue(quality.reasons().contains("orientation_accuracy_high"));
        assertTrue(quality.recommendedActions().isEmpty());
    }

    @Test
    void recommendsCalibrationAndSlowerMotionForWeakTelemetry() {
        var quality = CameraTelemetryQualityPolicy.evaluate(
                60.0,
                40.0,
                80.0,
                70.0,
                9.5,
                null);

        assertEquals(15, quality.score());
        assertEquals("low", quality.level());
        assertEquals("driving", quality.motionState());
        assertTrue(quality.reasons().contains("gps_accuracy_low"));
        assertTrue(quality.reasons().contains("altitude_accuracy_low"));
        assertTrue(quality.reasons().contains("orientation_accuracy_low"));
        assertTrue(quality.reasons().contains("motion_fast"));
        assertTrue(quality.recommendedActions().contains("move_to_open_sky"));
        assertTrue(quality.recommendedActions().contains("wait_for_altitude_lock"));
        assertTrue(quality.recommendedActions().contains("calibrate_compass"));
        assertTrue(quality.recommendedActions().contains("slow_down_for_ar"));
    }
}
