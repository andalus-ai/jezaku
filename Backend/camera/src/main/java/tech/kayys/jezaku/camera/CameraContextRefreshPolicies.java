package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextRefresh;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;

import java.util.Comparator;
import java.util.List;

final class CameraContextRefreshPolicies {
    private CameraContextRefreshPolicies() {
    }

    static CameraContextRefresh from(CameraContextSummary summary, List<CameraLayer> layers) {
        Integer nextExpiringDotSeconds = nextExpiringDotSeconds(layers);
        RefreshBase base = base(summary);
        int recommendedPollSeconds = applyExpiryCap(base.pollSeconds(), nextExpiringDotSeconds);
        return new CameraContextRefresh(
                recommendedPollSeconds,
                recommendedPollSeconds,
                nextExpiringDotSeconds,
                base.reason());
    }

    private static RefreshBase base(CameraContextSummary summary) {
        if (summary.blockingAdvisoryCount() > 0 || summary.criticalAdvisoryCount() > 0) {
            return new RefreshBase(2, CameraSyncContract.REFRESH_REASON_BLOCKING_ADVISORY);
        }
        if (summary.warningAdvisoryCount() > 0) {
            return new RefreshBase(5, CameraSyncContract.REFRESH_REASON_WARNING_ADVISORY);
        }
        if (summary.liveCount() > 0) {
            return new RefreshBase(5, CameraSyncContract.REFRESH_REASON_LIVE_ACTIVITY);
        }
        if (summary.freshCount() > 0) {
            return new RefreshBase(15, CameraSyncContract.REFRESH_REASON_AMBIENT);
        }
        return new RefreshBase(30, CameraSyncContract.REFRESH_REASON_IDLE);
    }

    private static int applyExpiryCap(int pollSeconds, Integer nextExpiringDotSeconds) {
        if (nextExpiringDotSeconds == null) {
            return pollSeconds;
        }
        return Math.max(1, Math.min(pollSeconds, nextExpiringDotSeconds));
    }

    private static Integer nextExpiringDotSeconds(List<CameraLayer> layers) {
        return layers.stream()
                .flatMap(layer -> layer.dots().stream())
                .map(dot -> dot.expiresInSeconds())
                .filter(value -> value != null)
                .min(Comparator.naturalOrder())
                .map(Long::intValue)
                .orElse(null);
    }

    private record RefreshBase(int pollSeconds, String reason) {
    }
}
