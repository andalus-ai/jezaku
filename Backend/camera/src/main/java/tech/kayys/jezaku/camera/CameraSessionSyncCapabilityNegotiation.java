package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilities;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionSyncCapabilityReference;

record CameraSessionSyncCapabilityNegotiation(
        String mode,
        CameraSessionSyncCapabilityReference reference,
        CameraSessionSyncCapabilities capabilities) {
    static CameraSessionSyncCapabilityNegotiation from(
            String capabilitiesMode,
            String capabilitiesEtag,
            CameraSessionSyncSectionSelection sectionSelection) {
        String normalizedMode = normalizedMode(capabilitiesMode);
        boolean includeCapabilities = CameraSyncContract.CAPABILITIES_MODE_FULL.equals(normalizedMode)
                && sectionSelection.includes(CameraSyncContract.SYNC_SECTION_CAPABILITIES);
        CameraSessionSyncCapabilities capabilities = includeCapabilities
                ? CameraSessionSyncCapabilityCatalog.current()
                : null;
        CameraSessionSyncCapabilityReference reference = CameraSessionSyncCapabilityCatalog.reference(
                normalizedMode,
                capabilitiesEtag,
                includeCapabilities);
        return new CameraSessionSyncCapabilityNegotiation(normalizedMode, reference, capabilities);
    }

    private static String normalizedMode(String value) {
        String normalized = value == null || value.isBlank()
                ? CameraSyncContract.DEFAULT_CAPABILITIES_MODE
                : value.trim().toLowerCase();
        if (CameraSyncContract.SUPPORTED_CAPABILITIES_MODES.contains(normalized)) {
            return normalized;
        }
        throw new BadRequestException("capabilitiesMode must be full or etag");
    }
}
