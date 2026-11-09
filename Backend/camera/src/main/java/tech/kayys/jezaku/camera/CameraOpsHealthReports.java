package tech.kayys.jezaku.camera;

import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraAdvisory;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerOpsHealth;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSource;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayerSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraOpsHealthResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.CameraVisibilityReport;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

final class CameraOpsHealthReports {
    private static final int DEFAULT_MAX_SOURCE_AGE_SECONDS = 30;
    private static final int DEGRADED_LAYER_PENALTY = 15;
    private static final int CRITICAL_LAYER_PENALTY = 35;
    private static final int STALE_LAYER_PENALTY = 10;

    private CameraOpsHealthReports() {
    }

    static CameraOpsHealthResponse from(CameraContextResponse context, Instant now) {
        Instant generatedAt = now == null ? Instant.now() : now;
        List<CameraLayer> layers = context == null || context.layers() == null
                ? List.of()
                : context.layers();
        int maxAgeSeconds = context == null || context.refresh() == null
                ? DEFAULT_MAX_SOURCE_AGE_SECONDS
                : Math.max(1, context.refresh().maxAgeSeconds());
        List<CameraLayerOpsHealth> layerReports = layers.stream()
                .map(layer -> layerHealth(layer, maxAgeSeconds, generatedAt))
                .toList();

        int degradedLayerCount = countHealth(layerReports, "degraded");
        int criticalLayerCount = countHealth(layerReports, "critical");
        int staleLayerCount = (int) layerReports.stream().filter(CameraLayerOpsHealth::stale).count();
        List<CameraAdvisory> advisories = advisories(layerReports, context);
        int score = Math.max(0, 100
                - degradedLayerCount * DEGRADED_LAYER_PENALTY
                - criticalLayerCount * CRITICAL_LAYER_PENALTY
                - staleLayerCount * STALE_LAYER_PENALTY);
        return new CameraOpsHealthResponse(
                overallStatus(degradedLayerCount, criticalLayerCount),
                score,
                layerReports.size(),
                countHealth(layerReports, "healthy"),
                degradedLayerCount,
                criticalLayerCount,
                (int) layerReports.stream().filter(report -> fallback(report.source())).count(),
                (int) layerReports.stream().filter(report -> !"ready".equals(report.layerStatus())).count(),
                staleLayerCount,
                (int) layerReports.stream().filter(CameraLayerOpsHealth::truncated).count(),
                distinct(layerReports.stream()
                        .flatMap(report -> report.issues().stream())
                        .toList()),
                distinct(layerReports.stream()
                        .flatMap(report -> report.recommendedActions().stream())
                        .toList()),
                advisories,
                layerReports,
                generatedAt);
    }

    private static CameraLayerOpsHealth layerHealth(CameraLayer layer, int maxAgeSeconds, Instant now) {
        List<String> issues = new ArrayList<>();
        List<String> actions = new ArrayList<>();
        CameraLayerSource source = layer == null ? null : layer.source();
        String layerName = layer == null ? "unknown" : layer.layer();
        String layerStatus = layer == null ? "unavailable" : layer.status();
        CameraVisibilityReport visibility = layer == null ? null : layer.visibility();
        Long sourceAgeSeconds = sourceAgeSeconds(source, now);
        boolean stale = false;
        boolean degraded = false;
        boolean critical = false;

        if (!"ready".equals(layerStatus)) {
            critical = true;
            issues.add("layer_unavailable");
            actions.add("restore_" + token(layerName, "layer") + "_layer");
        }
        if (source == null) {
            critical = true;
            issues.add("source_missing");
            actions.add("inspect_layer_source_mapping");
        } else {
            if (sourceAgeSeconds == null) {
                degraded = true;
                issues.add("fetched_at_missing");
                actions.add("ensure_source_timestamp");
            } else if (sourceAgeSeconds > maxAgeSeconds) {
                stale = true;
                degraded = true;
                issues.add("source_stale");
                actions.add("refresh_camera_context");
            }
            if (source.fallback()) {
                degraded = true;
                issues.add("fallback_active");
                actions.add("restore_" + token(source.requestedSource(), "requested") + "_source");
            } else if (!source.healthy()) {
                critical = true;
                issues.add("source_unhealthy");
                actions.add("restore_" + token(source.effectiveSource(), layerName) + "_source");
            }
        }
        if (layer != null && layer.truncated()) {
            issues.add("layer_truncated");
            actions.add("raise_limit_per_layer_or_page_results");
        }
        VisibilityHealth visibilityHealth = visibilityHealth(visibility);
        degraded = degraded || visibilityHealth.degraded();
        critical = critical || visibilityHealth.critical();
        issues.addAll(visibilityHealth.issues());
        actions.addAll(visibilityHealth.recommendedActions());
        VisibilityHealth memoryAnchorHealth = memoryAnchorHealth(layer);
        degraded = degraded || memoryAnchorHealth.degraded();
        critical = critical || memoryAnchorHealth.critical();
        issues.addAll(memoryAnchorHealth.issues());
        actions.addAll(memoryAnchorHealth.recommendedActions());
        String health = critical ? "critical" : degraded ? "degraded" : "healthy";
        return new CameraLayerOpsHealth(
                layerName,
                layerStatus,
                health,
                source,
                layer == null ? 0 : layer.count(),
                layer == null ? 0 : layer.totalAvailable(),
                layer != null && layer.truncated(),
                sourceAgeSeconds,
                stale,
                visibility,
                distinct(issues),
                distinct(actions));
    }

    private static VisibilityHealth visibilityHealth(CameraVisibilityReport visibility) {
        if (visibility == null) {
            return VisibilityHealth.healthy();
        }
        List<String> issues = new ArrayList<>();
        List<String> actions = new ArrayList<>();
        boolean degraded = false;
        boolean critical = false;
        String health = visibility.audienceHealth() == null
                ? "unknown"
                : visibility.audienceHealth().trim().toLowerCase(Locale.ROOT);
        if (visibility.audienceFallback()) {
            degraded = true;
            issues.add("visibility_audience_fallback");
            actions.add(restoreAudienceAction(visibility));
        }
        switch (health) {
            case "healthy" -> {
            }
            case "critical" -> {
                critical = true;
                issues.add("visibility_audience_critical");
                actions.add(restoreAudienceAction(visibility));
            }
            case "degraded" -> {
                degraded = true;
                issues.add("visibility_audience_degraded");
                actions.add(restoreAudienceAction(visibility));
            }
            case "unknown", "" -> {
                degraded = true;
                issues.add("visibility_audience_unknown");
                actions.add("inspect_visibility_audience_health");
            }
            default -> {
                degraded = true;
                issues.add("visibility_audience_degraded");
                actions.add(restoreAudienceAction(visibility));
            }
        }
        return new VisibilityHealth(degraded, critical, distinct(issues), distinct(actions));
    }

    private static VisibilityHealth memoryAnchorHealth(CameraLayer layer) {
        if (layer == null || !"memories".equals(layer.layer()) || layer.summary() == null) {
            return VisibilityHealth.healthy();
        }
        CameraLayerSummary summary = layer.summary();
        List<String> issues = new ArrayList<>();
        List<String> actions = new ArrayList<>();
        if (summary.needsRefinementMemoryCount() > 0) {
            issues.add("memory_anchor_refinement_needed");
            actions.add("review_anchor");
        }
        if (summary.lowConfidenceMemoryCount() > 0) {
            issues.add("memory_anchor_low_confidence");
            actions.add("review_anchor");
        }
        return issues.isEmpty()
                ? VisibilityHealth.healthy()
                : new VisibilityHealth(true, false, distinct(issues), distinct(actions));
    }

    private static String restoreAudienceAction(CameraVisibilityReport visibility) {
        return "restore_" + token(visibility == null ? null : visibility.audienceSource(), "audience")
                + "_audience_access";
    }

    private static Long sourceAgeSeconds(CameraLayerSource source, Instant now) {
        if (source == null || source.fetchedAt() == null || now == null) {
            return null;
        }
        return Math.max(0, Duration.between(source.fetchedAt(), now).toSeconds());
    }

    private static int countHealth(List<CameraLayerOpsHealth> reports, String health) {
        return (int) reports.stream()
                .filter(report -> health.equals(report.health()))
                .count();
    }

    private static boolean fallback(CameraLayerSource source) {
        return source != null && source.fallback();
    }

    private static List<CameraAdvisory> advisories(
            List<CameraLayerOpsHealth> reports,
            CameraContextResponse context) {
        return reports.stream()
                .filter(report -> !"healthy".equals(report.health()))
                .map(report -> advisory(report, context))
                .sorted((left, right) -> {
                    int priority = Integer.compare(right.priority(), left.priority());
                    return priority != 0 ? priority : left.layer().compareTo(right.layer());
                })
                .toList();
    }

    private static CameraAdvisory advisory(CameraLayerOpsHealth report, CameraContextResponse context) {
        String severity = "critical".equals(report.health()) ? "critical" : "warning";
        return new CameraAdvisory(
                severity,
                "critical".equals(severity) ? 850 : 620,
                "critical".equals(severity) ? "banner" : "hint",
                report.layer(),
                "layer",
                report.layer(),
                layerTitle(report),
                layerMessage(report),
                report.recommendedActions().isEmpty() ? null : report.recommendedActions().getFirst(),
                opsHealthHref(context, report.layer()),
                null);
    }

    private static String opsHealthHref(CameraContextResponse context, String layer) {
        if (context == null || context.telemetry() == null || context.telemetry().position() == null) {
            return "/camera/ops/health?layers=" + encode(layer);
        }

        CameraTelemetry telemetry = context.telemetry();
        GeoPoint position = telemetry.position();
        List<String> query = new ArrayList<>();
        addQuery(query, "viewerId", context.viewerId());
        addQuery(query, "lat", position.latitude());
        addQuery(query, "lng", position.longitude());
        addQuery(query, "altitudeMeters", position.altitudeMeters());
        addQuery(query, "headingDegrees", telemetry.headingDegrees());
        addQuery(query, "compassDegrees", telemetry.compassDegrees());
        addQuery(query, "speedMetersPerSecond", telemetry.speedMetersPerSecond());
        addQuery(query, "radiusMeters", telemetry.radiusMeters());
        addQuery(query, "layers", layer);
        return "/camera/ops/health?" + String.join("&", query);
    }

    private static void addQuery(List<String> query, String name, Object value) {
        if (value == null) {
            return;
        }
        query.add(encode(name) + "=" + encode(String.valueOf(value)));
    }

    private static String encode(String value) {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
    }

    private static String layerTitle(CameraLayerOpsHealth report) {
        boolean offline = "critical".equals(report.health())
                && (report.issues().contains("layer_unavailable")
                        || report.issues().contains("source_missing")
                        || report.issues().contains("source_unhealthy"));
        return label(report.layer()) + " " + (offline ? "offline" : "needs attention");
    }

    private static String layerMessage(CameraLayerOpsHealth report) {
        String label = label(report.layer());
        if (report.issues().contains("layer_unavailable")) {
            return label + " is unavailable.";
        }
        if (report.issues().contains("source_unhealthy")) {
            return label + " source is unhealthy.";
        }
        if (report.issues().contains("fallback_active")) {
            return label + " is using fallback data.";
        }
        if (report.issues().contains("source_stale")) {
            return label + " data is stale.";
        }
        if (report.issues().contains("fetched_at_missing")) {
            return label + " source timestamp is missing.";
        }
        if (report.issues().contains("visibility_audience_critical")) {
            return label + " audience visibility is critical.";
        }
        if (report.issues().contains("visibility_audience_fallback")) {
            return label + " audience visibility is using fallback data.";
        }
        if (report.issues().contains("visibility_audience_degraded")) {
            return label + " audience visibility is degraded.";
        }
        if (report.issues().contains("visibility_audience_unknown")) {
            return label + " audience visibility health is unknown.";
        }
        if (report.issues().contains("memory_anchor_refinement_needed")) {
            return label + " has memory anchors needing refinement.";
        }
        if (report.issues().contains("memory_anchor_low_confidence")) {
            return label + " has low-confidence memory anchors.";
        }
        if (report.issues().contains("layer_truncated")) {
            return label + " has more results than returned.";
        }
        return label + " needs attention.";
    }

    private static String label(String layer) {
        if (layer == null || layer.isBlank()) {
            return "Layer";
        }
        return switch (layer) {
            case "safety" -> "Safety layer";
            case "people" -> "People layer";
            case "memories" -> "Memories layer";
            default -> layer + " layer";
        };
    }

    private static String overallStatus(int degradedLayerCount, int criticalLayerCount) {
        if (criticalLayerCount > 0) {
            return "critical";
        }
        if (degradedLayerCount > 0) {
            return "degraded";
        }
        return "healthy";
    }

    private static List<String> distinct(List<String> values) {
        Set<String> result = new LinkedHashSet<>();
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                result.add(value);
            }
        }
        return List.copyOf(result);
    }

    private static String token(String value, String fallback) {
        String normalized = value == null || value.isBlank() ? fallback : value;
        normalized = normalized.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "_");
        normalized = normalized.replaceAll("^_+|_+$", "");
        return normalized.isBlank() ? fallback : normalized;
    }

    private record VisibilityHealth(
            boolean degraded,
            boolean critical,
            List<String> issues,
            List<String> recommendedActions) {
        static VisibilityHealth healthy() {
            return new VisibilityHealth(false, false, List.of(), List.of());
        }
    }
}
