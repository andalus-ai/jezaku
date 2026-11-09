package tech.kayys.jezaku.camera;

record CameraSessionSyncWorkPlan(
        boolean needsSyncPlan,
        boolean needsContextDelta,
        boolean needsOpsHealth) {
    static CameraSessionSyncWorkPlan from(CameraSessionSyncSectionSelection sectionSelection) {
        boolean needsSyncPlan = sectionSelection.includes(CameraSyncContract.SYNC_SECTION_SYNC_PLAN)
                || sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CLIENT_HINTS)
                || sectionSelection.includes(CameraSyncContract.SYNC_SECTION_FRESHNESS);
        boolean needsContextDelta = sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CONTEXT_DELTA)
                || needsSyncPlan;
        boolean needsOpsHealth = sectionSelection.includes(CameraSyncContract.SYNC_SECTION_OPS_HEALTH)
                || needsSyncPlan;
        return new CameraSessionSyncWorkPlan(needsSyncPlan, needsContextDelta, needsOpsHealth);
    }
}
