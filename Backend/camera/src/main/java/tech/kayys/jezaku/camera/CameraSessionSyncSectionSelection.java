package tech.kayys.jezaku.camera;

import jakarta.ws.rs.BadRequestException;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

record CameraSessionSyncSectionSelection(List<String> sections, boolean allSections) {
    static CameraSessionSyncSectionSelection from(String rawValue) {
        String raw = rawValue == null ? "" : rawValue.trim();
        if (raw.isBlank() || CameraSyncContract.DEFAULT_SYNC_RESPONSE_SECTIONS.equals(raw)) {
            return all();
        }

        Set<String> requested = new LinkedHashSet<>();
        for (String token : raw.split(",")) {
            String section = token.trim();
            if (!section.isBlank()) {
                requested.add(section);
            }
        }
        if (requested.isEmpty()) {
            return all();
        }

        List<String> unsupported = requested.stream()
                .filter(section -> !CameraSyncContract.SUPPORTED_SYNC_RESPONSE_SECTIONS.contains(section))
                .toList();
        if (!unsupported.isEmpty()) {
            throw new BadRequestException("sections contains unsupported sync response section: "
                    + String.join(",", unsupported));
        }

        List<String> canonical = CameraSyncContract.SUPPORTED_SYNC_RESPONSE_SECTIONS.stream()
                .filter(requested::contains)
                .toList();
        return new CameraSessionSyncSectionSelection(List.copyOf(canonical), false);
    }

    boolean includes(String section) {
        return sections.contains(section);
    }

    String queryValue() {
        return allSections ? null : String.join(",", sections);
    }

    private static CameraSessionSyncSectionSelection all() {
        return new CameraSessionSyncSectionSelection(
                CameraSyncContract.SUPPORTED_SYNC_RESPONSE_SECTIONS,
                true);
    }
}
