package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextDeltaResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncPlan;

import java.time.Instant;

final class CameraSessionSyncPlans {
    private CameraSessionSyncPlans() {
    }

    static CameraSessionSyncPlan from(
            CameraSessionResponse session,
            CameraContextResponse context,
            CameraSessionEventListResponse events,
            CameraContextDeltaResponse contextDelta,
            Instant generatedAt) {
        return from(session, context, events, contextDelta, null, generatedAt);
    }

    static CameraSessionSyncPlan from(
            CameraSessionResponse session,
            CameraContextResponse context,
            CameraSessionEventListResponse events,
            CameraContextDeltaResponse contextDelta,
            CameraOpsHealthResponse opsHealth,
            Instant generatedAt) {
        int recommendedSyncAfterSeconds = context.refresh().recommendedPollSeconds();
        int maxContextAgeSeconds = context.refresh().maxAgeSeconds();
        String reason = context.refresh().reason();
        boolean eventBacklog = events.hasMore();
        boolean deltaBacklog = contextDelta != null && contextDelta.truncated();

        if (deltaBacklog) {
            recommendedSyncAfterSeconds = 1;
            reason = CameraSyncContract.SYNC_REASON_DELTA_BACKLOG;
        } else if (eventBacklog) {
            recommendedSyncAfterSeconds = 1;
            reason = CameraSyncContract.SYNC_REASON_EVENT_BACKLOG;
        } else if (opsHealth != null && "critical".equals(opsHealth.status())) {
            recommendedSyncAfterSeconds = Math.min(recommendedSyncAfterSeconds, 2);
            maxContextAgeSeconds = Math.min(maxContextAgeSeconds, 2);
            reason = CameraSyncContract.SYNC_REASON_OPS_HEALTH_CRITICAL;
        } else if (opsHealth != null && "degraded".equals(opsHealth.status())) {
            recommendedSyncAfterSeconds = Math.min(recommendedSyncAfterSeconds, 5);
            maxContextAgeSeconds = Math.min(maxContextAgeSeconds, 5);
            reason = CameraSyncContract.SYNC_REASON_OPS_HEALTH_DEGRADED;
        }

        return new CameraSessionSyncPlan(
                recommendedSyncAfterSeconds,
                generatedAt.plusSeconds(recommendedSyncAfterSeconds),
                maxContextAgeSeconds,
                generatedAt.plusSeconds(maxContextAgeSeconds),
                session.guidance().heartbeatAfterSeconds(),
                dueAt(generatedAt, session.guidance().heartbeatAfterSeconds()),
                session.guidance().positionUpdateAfterSeconds(),
                dueAt(generatedAt, session.guidance().positionUpdateAfterSeconds()),
                eventBacklog,
                deltaBacklog,
                reason);
    }

    private static Instant dueAt(Instant generatedAt, Integer afterSeconds) {
        return afterSeconds == null ? null : generatedAt.plusSeconds(afterSeconds);
    }
}
