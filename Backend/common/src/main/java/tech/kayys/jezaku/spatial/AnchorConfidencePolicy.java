package tech.kayys.jezaku.spatial;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;

public final class AnchorConfidencePolicy {
    private AnchorConfidencePolicy() {
    }

    public static AnchorConfidence evaluate(
            String anchorType,
            boolean hasAltitude,
            Double headingDegrees,
            Double compassDegrees,
            Double pitchDegrees,
            Double rollDegrees,
            Double gpsAccuracyMeters) {
        String level = level(hasAltitude, headingDegrees, compassDegrees, gpsAccuracyMeters);
        List<String> reasons = new ArrayList<>();
        LinkedHashSet<String> recommendedActions = new LinkedHashSet<>();
        int score = anchorTypeScore(anchorType, reasons);

        score += gpsAccuracyScore(gpsAccuracyMeters, reasons, recommendedActions);
        score += orientationScore(headingDegrees, compassDegrees, reasons, recommendedActions);
        score += altitudeScore(hasAltitude, reasons, recommendedActions);
        score += poseScore(pitchDegrees, rollDegrees, reasons, recommendedActions);
        return new AnchorConfidence(
                scoreForLevel(level, score),
                level,
                List.copyOf(reasons),
                List.copyOf(recommendedActions));
    }

    private static String level(
            boolean hasAltitude,
            Double headingDegrees,
            Double compassDegrees,
            Double gpsAccuracyMeters) {
        boolean hasOrientation = headingDegrees != null || compassDegrees != null;
        if (gpsAccuracyMeters != null && gpsAccuracyMeters <= 5.0 && hasOrientation && hasAltitude) {
            return "high";
        }
        if (gpsAccuracyMeters != null && gpsAccuracyMeters <= 15.0 && hasOrientation) {
            return "medium";
        }
        return "low";
    }

    private static int anchorTypeScore(String anchorType, List<String> reasons) {
        if ("hybrid".equals(anchorType)) {
            reasons.add("anchor_type_hybrid");
            return 5;
        }
        if ("visual".equals(anchorType)) {
            reasons.add("anchor_type_visual");
            return 4;
        }
        reasons.add("anchor_type_geo");
        return 3;
    }

    private static int gpsAccuracyScore(
            Double accuracy,
            List<String> reasons,
            LinkedHashSet<String> recommendedActions) {
        if (accuracy == null) {
            reasons.add("gps_accuracy_missing");
            recommendedActions.add("recapture_with_better_gps");
            return 0;
        }
        if (accuracy <= 5.0) {
            reasons.add("gps_accuracy_high");
            return 45;
        }
        if (accuracy <= 15.0) {
            reasons.add("gps_accuracy_medium");
            return 35;
        }
        if (accuracy <= 50.0) {
            reasons.add("gps_accuracy_low");
            recommendedActions.add("recapture_with_better_gps");
            return 15;
        }
        reasons.add("gps_accuracy_poor");
        recommendedActions.add("recapture_with_better_gps");
        return 0;
    }

    private static int orientationScore(
            Double headingDegrees,
            Double compassDegrees,
            List<String> reasons,
            LinkedHashSet<String> recommendedActions) {
        boolean hasHeading = headingDegrees != null;
        boolean hasCompass = compassDegrees != null;
        if (hasHeading && hasCompass) {
            reasons.add("orientation_heading_and_compass");
            return 20;
        }
        if (hasHeading || hasCompass) {
            reasons.add("orientation_partial");
            return 16;
        }
        reasons.add("orientation_missing");
        recommendedActions.add("calibrate_compass");
        return 0;
    }

    private static int altitudeScore(
            boolean hasAltitude,
            List<String> reasons,
            LinkedHashSet<String> recommendedActions) {
        if (hasAltitude) {
            reasons.add("altitude_present");
            return 20;
        }
        reasons.add("altitude_missing");
        recommendedActions.add("enable_altitude");
        return 0;
    }

    private static int poseScore(
            Double pitchDegrees,
            Double rollDegrees,
            List<String> reasons,
            LinkedHashSet<String> recommendedActions) {
        boolean hasPitch = pitchDegrees != null;
        boolean hasRoll = rollDegrees != null;
        if (hasPitch && hasRoll) {
            reasons.add("pose_pitch_and_roll");
            return 10;
        }
        if (hasPitch || hasRoll) {
            reasons.add("pose_partial");
            recommendedActions.add("stabilize_camera_pose");
            return 5;
        }
        reasons.add("pose_missing");
        recommendedActions.add("stabilize_camera_pose");
        return 0;
    }

    private static int scoreForLevel(String level, int score) {
        if ("high".equals(level)) {
            return Math.min(100, Math.max(80, score));
        }
        if ("medium".equals(level)) {
            return Math.min(79, Math.max(60, score));
        }
        return Math.min(59, Math.max(0, score));
    }

    public record AnchorConfidence(
            int score,
            String level,
            List<String> reasons,
            List<String> recommendedActions) {
    }
}
