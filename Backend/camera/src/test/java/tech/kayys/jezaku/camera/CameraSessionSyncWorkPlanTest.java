package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraSessionSyncWorkPlanTest {
    @Test
    void fullSyncNeedsAllDerivedWork() {
        CameraSessionSyncWorkPlan workPlan = CameraSessionSyncWorkPlan.from(
                CameraSessionSyncSectionSelection.from(null));

        assertTrue(workPlan.needsSyncPlan());
        assertTrue(workPlan.needsContextDelta());
        assertTrue(workPlan.needsOpsHealth());
    }

    @Test
    void linkOnlySyncSkipsSecondaryDerivedWork() {
        CameraSessionSyncWorkPlan workPlan = CameraSessionSyncWorkPlan.from(
                CameraSessionSyncSectionSelection.from("links"));

        assertFalse(workPlan.needsSyncPlan());
        assertFalse(workPlan.needsContextDelta());
        assertFalse(workPlan.needsOpsHealth());
    }

    @Test
    void clientHintsAndFreshnessDependOnSyncPlanInputs() {
        CameraSessionSyncWorkPlan clientHints = CameraSessionSyncWorkPlan.from(
                CameraSessionSyncSectionSelection.from("clientHints"));
        CameraSessionSyncWorkPlan freshness = CameraSessionSyncWorkPlan.from(
                CameraSessionSyncSectionSelection.from("freshness"));

        assertTrue(clientHints.needsSyncPlan());
        assertTrue(clientHints.needsContextDelta());
        assertTrue(clientHints.needsOpsHealth());
        assertTrue(freshness.needsSyncPlan());
        assertTrue(freshness.needsContextDelta());
        assertTrue(freshness.needsOpsHealth());
    }

    @Test
    void directHealthSectionsOnlyNeedTheirOwnDerivedWork() {
        CameraSessionSyncWorkPlan contextDelta = CameraSessionSyncWorkPlan.from(
                CameraSessionSyncSectionSelection.from("contextDelta"));
        CameraSessionSyncWorkPlan opsHealth = CameraSessionSyncWorkPlan.from(
                CameraSessionSyncSectionSelection.from("opsHealth"));

        assertFalse(contextDelta.needsSyncPlan());
        assertTrue(contextDelta.needsContextDelta());
        assertFalse(contextDelta.needsOpsHealth());
        assertFalse(opsHealth.needsSyncPlan());
        assertFalse(opsHealth.needsContextDelta());
        assertTrue(opsHealth.needsOpsHealth());
    }
}
