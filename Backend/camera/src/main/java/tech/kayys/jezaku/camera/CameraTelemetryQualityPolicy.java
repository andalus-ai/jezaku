package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetryQuality;

import java.util.ArrayList;
import java.util.List;

final class CameraTelemetryQualityPolicy {
    private CameraTelemetryQualityPolicy() {
    }

    static CameraTelemetryQuality evaluate(
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            Double speedMetersPerSecond,
            String motionState) {
        List<String> reasons = new ArrayList<>();
        List<String> actions = new ArrayList<>();
        int score = 100;
        String normalizedMotionState = motionState == null ? inferMotionState(speedMetersPerSecond) : motionState;

        score -= gpsPenalty(gpsAccuracyMeters, reasons, actions);
        score -= altitudePenalty(altitudeAccuracyMeters, reasons, actions);
        score -= orientationPenalty(headingAccuracyDegrees, compassAccuracyDegrees, reasons, actions);
        score -= motionPenalty(speedMetersPerSecond, normalizedMotionState, reasons, actions);

        int normalizedScore = Math.max(0, Math.min(100, score));
        return new CameraTelemetryQuality(
                normalizedScore,
                level(normalizedScore),
                normalizedMotionState,
                gpsAccuracyMeters,
                altitudeAccuracyMeters,
                headingAccuracyDegrees,
                compassAccuracyDegrees,
                List.copyOf(reasons),
                List.copyOf(actions));
    }

    private static int gpsPenalty(Double accuracy, List<String> reasons, List<String> actions) {
        if (accuracy == null) {
            reasons.add("gps_accuracy_missing");
            addAction(actions, "enable_precise_location");
            return 15;
        }
        if (accuracy <= 10.0) {
            reasons.add("gps_accuracy_high");
            return 0;
        }
        if (accuracy <= 25.0) {
            reasons.add("gps_accuracy_medium");
            addAction(actions, "move_to_open_sky");
            return 10;
        }
        reasons.add("gps_accuracy_low");
        addAction(actions, "move_to_open_sky");
        return 30;
    }

    private static int altitudePenalty(Double accuracy, List<String> reasons, List<String> actions) {
        if (accuracy == null) {
            reasons.add("altitude_accuracy_missing");
            return 5;
        }
        if (accuracy <= 8.0) {
            reasons.add("altitude_accuracy_high");
            return 0;
        }
        if (accuracy <= 25.0) {
            reasons.add("altitude_accuracy_medium");
            return 5;
        }
        reasons.add("altitude_accuracy_low");
        addAction(actions, "wait_for_altitude_lock");
        return 15;
    }

    private static int orientationPenalty(
            Double headingAccuracy,
            Double compassAccuracy,
            List<String> reasons,
            List<String> actions) {
        Double bestAccuracy = bestAccuracy(headingAccuracy, compassAccuracy);
        if (bestAccuracy == null) {
            reasons.add("orientation_accuracy_missing");
            addAction(actions, "calibrate_compass");
            return 10;
        }
        if (bestAccuracy <= 15.0) {
            reasons.add("orientation_accuracy_high");
            return 0;
        }
        if (bestAccuracy <= 45.0) {
            reasons.add("orientation_accuracy_medium");
            addAction(actions, "calibrate_compass");
            return 10;
        }
        reasons.add("orientation_accuracy_low");
        addAction(actions, "calibrate_compass");
        return 25;
    }

    private static int motionPenalty(Double speedMetersPerSecond, String motionState, List<String> reasons,
            List<String> actions) {
        double speed = speedMetersPerSecond == null ? 0.0 : speedMetersPerSecond;
        if (speed >= 8.0 || "driving".equals(motionState)) {
            reasons.add("motion_fast");
            addAction(actions, "slow_down_for_ar");
            return 15;
        }
        if (speed >= 3.0 || "running".equals(motionState)) {
            reasons.add("motion_unsteady");
            addAction(actions, "slow_down_for_ar");
            return 8;
        }
        reasons.add("motion_stable");
        return 0;
    }

    private static String inferMotionState(Double speedMetersPerSecond) {
        if (speedMetersPerSecond == null) {
            return "unknown";
        }
        if (speedMetersPerSecond >= 8.0) {
            return "driving";
        }
        if (speedMetersPerSecond >= 3.0) {
            return "running";
        }
        if (speedMetersPerSecond >= 0.3) {
            return "walking";
        }
        return "stationary";
    }

    private static Double bestAccuracy(Double headingAccuracy, Double compassAccuracy) {
        if (headingAccuracy == null) {
            return compassAccuracy;
        }
        if (compassAccuracy == null) {
            return headingAccuracy;
        }
        return Math.min(headingAccuracy, compassAccuracy);
    }

    private static String level(int score) {
        if (score >= 80) {
            return "high";
        }
        if (score >= 55) {
            return "medium";
        }
        return "low";
    }

    private static void addAction(List<String> actions, String action) {
        if (!actions.contains(action)) {
            actions.add(action);
        }
    }
}
