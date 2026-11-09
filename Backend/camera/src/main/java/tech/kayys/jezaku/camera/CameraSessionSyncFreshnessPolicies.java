package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncFreshness;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;

import java.time.Instant;

final class CameraSessionSyncFreshnessPolicies {
    private static final String REASON_SYNC_PLAN_UNAVAILABLE = "sync_plan_unavailable";

    private CameraSessionSyncFreshnessPolicies() {
    }

    static CameraSessionSyncFreshness from(CameraSessionSyncPlan syncPlan, Instant generatedAt) {
        Instant effectiveGeneratedAt = generatedAt == null ? Instant.now() : generatedAt;
        if (syncPlan == null) {
            return new CameraSessionSyncFreshness(
                    effectiveGeneratedAt,
                    0,
                    effectiveGeneratedAt,
                    0,
                    effectiveGeneratedAt,
                    true,
                    true,
                    REASON_SYNC_PLAN_UNAVAILABLE);
        }

        int refreshAfterSeconds = Math.max(0, syncPlan.recommendedSyncAfterSeconds());
        int maxAgeSeconds = Math.max(0, syncPlan.maxContextAgeSeconds());
        Instant refreshRecommendedAt = syncPlan.nextSyncAt() == null
                ? effectiveGeneratedAt.plusSeconds(refreshAfterSeconds)
                : syncPlan.nextSyncAt();
        Instant staleAt = syncPlan.contextStaleAt() == null
                ? effectiveGeneratedAt.plusSeconds(maxAgeSeconds)
                : syncPlan.contextStaleAt();

        return new CameraSessionSyncFreshness(
                effectiveGeneratedAt,
                refreshAfterSeconds,
                refreshRecommendedAt,
                maxAgeSeconds,
                staleAt,
                refreshAfterSeconds <= 1,
                !staleAt.isAfter(effectiveGeneratedAt),
                syncPlan.reason());
    }
}
