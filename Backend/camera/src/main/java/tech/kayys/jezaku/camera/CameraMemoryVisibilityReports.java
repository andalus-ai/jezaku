package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReasonCount;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayDot;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryOverlayResponse;
import tech.kayys.jezaku.camera.CameraMemoryOverlayDtos.CameraMemoryVisibilityResult;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Builds memory overlay visibility results that can be reused by minimap, delta, and ops health surfaces.
 */
final class CameraMemoryVisibilityReports {
    private CameraMemoryVisibilityReports() {
    }

    static CameraMemoryVisibilityResult unreported(CameraMemoryOverlayResponse response) {
        return new CameraMemoryVisibilityResult(response, null);
    }

    static CameraMemoryVisibilityResult result(
            CameraMemoryOverlayResponse response,
            List<Candidate> candidates,
            String mode,
            String audienceSource,
            String audienceHealth,
            boolean audienceFallback) {
        List<CameraMemoryOverlayDot> dots = candidates.stream()
                .filter(Candidate::visible)
                .map(Candidate::dot)
                .toList();
        return new CameraMemoryVisibilityResult(
                filteredResponse(response, dots),
                report(mode, audienceSource, audienceHealth, audienceFallback, candidates));
    }

    static CameraVisibilityReport report(
            String mode,
            String audienceSource,
            String audienceHealth,
            boolean audienceFallback,
            List<Candidate> candidates) {
        int visibleCount = (int) candidates.stream()
                .filter(Candidate::visible)
                .count();
        return new CameraVisibilityReport(
                "memories",
                text(mode, "camera_local"),
                text(audienceSource, "local"),
                audienceHealth(audienceHealth),
                audienceFallback,
                candidates.size(),
                visibleCount,
                candidates.size() - visibleCount,
                hiddenReasonCounts(candidates));
    }

    static CameraMemoryOverlayResponse filteredResponse(
            CameraMemoryOverlayResponse response,
            List<CameraMemoryOverlayDot> dots) {
        int totalAvailable = dots.size() + Math.max(0, response.totalAvailableCount() - response.count());
        return new CameraMemoryOverlayResponse(
                dots.size(),
                totalAvailable,
                response.truncated() || totalAvailable > dots.size(),
                response.source(),
                dots);
    }

    static String sourceLabel(CameraMemoryOverlayResponse response) {
        if (response == null || response.source() == null || response.source().effectiveSource() == null) {
            return "local";
        }
        return response.source().effectiveSource();
    }

    static Candidate visible(CameraMemoryOverlayDot dot) {
        return new Candidate(dot, true, "visible");
    }

    static Candidate hidden(CameraMemoryOverlayDot dot, String reason) {
        return new Candidate(dot, false, visibilityReason(reason));
    }

    static String visibilityReason(String reason) {
        String normalized = token(reason);
        if (normalized.isBlank()) {
            return "visibility_hidden";
        }
        return CameraSyncContract.SUPPORTED_VISIBILITY_REASONS.contains(normalized)
                ? normalized
                : "visibility_hidden";
    }

    private static List<CameraVisibilityReasonCount> hiddenReasonCounts(List<Candidate> candidates) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        candidates.stream()
                .filter(candidate -> !candidate.visible())
                .forEach(candidate -> counts.merge(candidate.reason(), 1, Integer::sum));
        return counts.entrySet().stream()
                .map(entry -> new CameraVisibilityReasonCount(entry.getKey(), entry.getValue()))
                .toList();
    }

    private static String audienceHealth(String value) {
        String normalized = token(value);
        if (normalized.isBlank()) {
            return "healthy";
        }
        return CameraSyncContract.SUPPORTED_VISIBILITY_AUDIENCE_HEALTH_STATUSES.contains(normalized)
                ? normalized
                : "unknown";
    }

    private static String text(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private static String token(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String normalized = value.trim().toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "_");
        return normalized.replaceAll("^_+|_+$", "");
    }

    record Candidate(CameraMemoryOverlayDot dot, boolean visible, String reason) {
    }
}
