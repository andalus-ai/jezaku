package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.camera.CameraDtos.CameraAdvisory;
import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextFocus;
import tech.kayys.jezaku.camera.CameraDtos.CameraContextSummary;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetry;
import tech.kayys.jezaku.camera.CameraDtos.CameraTelemetryQuality;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import static tech.kayys.jezaku.geo.GeoMath.normalizeDegrees;
import static tech.kayys.jezaku.geo.GeoMath.orientationDegrees;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeOptionalBoundedDouble;
import static tech.kayys.jezaku.validation.RequestParams.normalizePositiveDouble;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;

@ApplicationScoped
public class CameraContextService {
    private static final Set<String> SUPPORTED_LAYERS = Set.copyOf(CameraSyncContract.SUPPORTED_LAYERS);
    private static final Set<String> MOTION_STATES = Set.of(
            "unknown",
            "stationary",
            "walking",
            "running",
            "driving");

    @Inject
    Instance<CameraOverlayProvider> overlayProviders;

    public Uni<CameraContextResponse> context(
            String viewerId,
            double lat,
            double lng,
            Double altitudeMeters,
            Double headingDegrees,
            Double compassDegrees,
            Double speedMetersPerSecond,
            Double gpsAccuracyMeters,
            Double altitudeAccuracyMeters,
            Double headingAccuracyDegrees,
            Double compassAccuracyDegrees,
            String motionState,
            Double radiusMeters,
            Integer limitPerLayer,
            String layers) {
        return Uni.createFrom().item(() -> {
            validateLatLng(lat, lng);
            Instant now = Instant.now();
            String viewer = optionalTrim(viewerId, "");
            GeoPoint origin = new GeoPoint(lat, lng, altitudeMeters);
            Double heading = normalizeDegrees(headingDegrees, "headingDegrees");
            Double compass = normalizeDegrees(compassDegrees, "compassDegrees");
            Double speed = normalizeOptionalBoundedDouble(
                    speedMetersPerSecond,
                    0.0,
                    100.0,
                    "speedMetersPerSecond");
            Double gpsAccuracy = normalizeOptionalBoundedDouble(
                    gpsAccuracyMeters,
                    0.0,
                    10_000.0,
                    "gpsAccuracyMeters");
            Double altitudeAccuracy = normalizeOptionalBoundedDouble(
                    altitudeAccuracyMeters,
                    0.0,
                    10_000.0,
                    "altitudeAccuracyMeters");
            Double headingAccuracy = normalizeOptionalBoundedDouble(
                    headingAccuracyDegrees,
                    0.0,
                    180.0,
                    "headingAccuracyDegrees");
            Double compassAccuracy = normalizeOptionalBoundedDouble(
                    compassAccuracyDegrees,
                    0.0,
                    180.0,
                    "compassAccuracyDegrees");
            String normalizedMotionState = normalizeMotionState(motionState, speed);
            double radius = normalizePositiveDouble(
                    radiusMeters,
                    CameraSyncContract.DEFAULT_RADIUS_METERS,
                    CameraSyncContract.MAX_RADIUS_METERS,
                    "radiusMeters");
            int limit = normalizeBoundedInt(
                    limitPerLayer,
                    CameraSyncContract.DEFAULT_LIMIT_PER_LAYER,
                    CameraSyncContract.MIN_LIMIT_PER_LAYER,
                    CameraSyncContract.MAX_LIMIT_PER_LAYER,
                    "limitPerLayer");
            List<String> requestedLayers = normalizeLayers(layers);
            double orientation = orientationDegrees(heading, compass);
            CameraTelemetryQuality quality = CameraTelemetryQualityPolicy.evaluate(
                    roundNullable(gpsAccuracy),
                    roundNullable(altitudeAccuracy),
                    roundNullable(headingAccuracy),
                    roundNullable(compassAccuracy),
                    speed == null ? null : round2(speed),
                    normalizedMotionState);
            CameraTelemetry telemetry = new CameraTelemetry(
                    viewer,
                    origin,
                    heading,
                    compass,
                    orientation,
                    speed == null ? null : round2(speed),
                    quality,
                    radius,
                    now);
            CameraOverlayQuery query = new CameraOverlayQuery(
                    viewer,
                    origin,
                    heading,
                    compass,
                    orientation,
                    radius,
                    limit,
                    now);
            return new CameraContextBase(viewer, telemetry, query, requestedLayers, now);
        }).chain(base -> providerLayers(base.query(), base.requestedLayers())
                .map(cameraLayers -> toResponse(base, cameraLayers)));
    }

    private int layerOrder(String layer) {
        return switch (layer) {
            case "safety" -> 0;
            case "people" -> 1;
            case "memories" -> 2;
            default -> 100;
        };
    }

    Uni<CameraLayer> safeLayer(CameraOverlayProvider provider, CameraOverlayQuery query) {
        String layer = layerName(provider);
        try {
            Uni<CameraLayer> response = provider.layer(query);
            if (response == null) {
                return Uni.createFrom().item(unavailableLayer(layer, "Layer unavailable", query.now()));
            }
            CameraLayer unavailable = unavailableLayer(layer, "Layer unavailable", query.now());
            return response
                    .map(layerResponse -> layerResponse == null ? unavailable : layerResponse)
                    .onFailure().recoverWithItem(unavailable);
        } catch (RuntimeException failure) {
            return Uni.createFrom().item(unavailableLayer(layer, "Layer unavailable", query.now()));
        }
    }

    private Uni<List<CameraLayer>> providerLayers(CameraOverlayQuery query, List<String> requestedLayers) {
        List<CameraOverlayProvider> providers = overlayProviders.stream()
                .filter(provider -> requestedLayers.contains(layerName(provider)))
                .sorted(Comparator.comparingInt(provider -> layerOrder(layerName(provider))))
                .toList();
        Uni<List<CameraLayer>> result = Uni.createFrom().item(List.of());
        for (CameraOverlayProvider provider : providers) {
            result = result.chain(cameraLayers -> safeLayer(provider, query)
                    .map(layer -> append(cameraLayers, layer)));
        }
        return result;
    }

    private List<String> normalizeLayers(String value) {
        if (value == null || value.isBlank()) {
            return CameraSyncContract.SUPPORTED_LAYERS;
        }
        List<String> requested = new ArrayList<>();
        for (String part : value.split(",")) {
            String layer = part.trim().toLowerCase(Locale.ROOT);
            if (layer.isEmpty()) {
                continue;
            }
            if (!SUPPORTED_LAYERS.contains(layer)) {
                throw new BadRequestException("layers must contain only safety, people, or memories");
            }
            if (!requested.contains(layer)) {
                requested.add(layer);
            }
        }
        if (requested.isEmpty()) {
            return CameraSyncContract.SUPPORTED_LAYERS;
        }
        return CameraSyncContract.SUPPORTED_LAYERS.stream()
                .filter(requested::contains)
                .toList();
    }

    private String normalizeMotionState(String motionState, Double speedMetersPerSecond) {
        return optionalChoice(
                motionState,
                inferMotionState(speedMetersPerSecond),
                MOTION_STATES,
                "motionState",
                "motionState must be unknown, stationary, walking, running, or driving");
    }

    private String inferMotionState(Double speedMetersPerSecond) {
        if (speedMetersPerSecond == null) {
            return "unknown";
        }
        if (speedMetersPerSecond >= 8.0) {
            return "driving";
        }
        if (speedMetersPerSecond >= 3.0) {
            return "running";
        }
        if (speedMetersPerSecond >= 0.3) {
            return "walking";
        }
        return "stationary";
    }

    private Double roundNullable(Double value) {
        return value == null ? null : round2(value);
    }

    private CameraContextResponse toResponse(CameraContextBase base, List<CameraLayer> layers) {
        int totalDots = layers.stream()
                .mapToInt(CameraLayer::count)
                .sum();
        List<CameraAdvisory> advisories = advisories(layers);
        CameraContextSummary summary = CameraContextSummaries.from(layers, advisories);
        return new CameraContextResponse(
                base.viewerId(),
                base.telemetry(),
                totalDots,
                advisories.size(),
                summary,
                focus(advisories, layers),
                CameraContextRefreshPolicies.from(summary, layers),
                CameraMinimapViewports.from(base.telemetry(), summary, layers, totalDots),
                advisories,
                layers,
                base.generatedAt());
    }

    private List<CameraLayer> append(List<CameraLayer> layers, CameraLayer layer) {
        List<CameraLayer> result = new ArrayList<>(layers);
        result.add(layer);
        return List.copyOf(result);
    }

    private CameraLayer unavailableLayer(String layer, String message, Instant now) {
        List<CameraDot> dots = List.of();
        return new CameraLayer(
                layer,
                "unavailable",
                message,
                CameraLayerSources.unavailable(layer, now),
                0,
                0,
                false,
                CameraLayerSummaries.from(dots),
                dots);
    }

    private List<CameraAdvisory> advisories(List<CameraLayer> layers) {
        List<CameraAdvisory> result = new ArrayList<>();
        for (CameraLayer layer : layers) {
            if ("safety".equals(layer.layer())) {
                layer.dots().stream()
                        .map(this::safetyAdvisory)
                        .filter(advisory -> advisory != null)
                        .forEach(result::add);
            }
            if ("memories".equals(layer.layer())) {
                CameraAdvisory memoryAdvisory = anchorRefinementAdvisory(layer);
                if (memoryAdvisory != null) {
                    result.add(memoryAdvisory);
                }
            }
            if (layer.truncated()) {
                result.add(truncationAdvisory(layer));
            }
        }
        return result.stream()
                .sorted(Comparator.comparingInt(CameraAdvisory::priority).reversed()
                        .thenComparingDouble(this::advisoryDistanceSortValue)
                        .thenComparing(CameraAdvisory::layer)
                        .thenComparing(CameraAdvisory::targetId))
                .toList();
    }

    private CameraContextFocus focus(List<CameraAdvisory> advisories, List<CameraLayer> layers) {
        if (!advisories.isEmpty()) {
            CameraAdvisory advisory = advisories.getFirst();
            CameraDot dot = matchingDot(advisory, layers);
            return new CameraContextFocus(
                    "advisory",
                    advisory.layer(),
                    advisory.targetType(),
                    advisory.targetId(),
                    advisory.title(),
                    advisory.message(),
                    advisory.actionType(),
                    advisory.href(),
                    advisory.displayMode(),
                    dot == null ? null : dot.anchor(),
                    advisory.priority(),
                    advisory.distanceMeters(),
                    dot == null ? null : dot.bearingDegrees(),
                    dot == null ? null : dot.relativeBearingDegrees(),
                    dot == null ? null : dot.relativeX(),
                    dot == null ? null : dot.relativeY(),
                    dot == null ? null : dot.altitudeDeltaMeters());
        }
        return layers.stream()
                .flatMap(layer -> layer.dots().stream())
                .sorted(Comparator.comparingDouble(CameraDot::distanceMeters)
                        .thenComparingInt(dot -> layerOrder(dot.layer()))
                        .thenComparing(CameraDot::targetId))
                .findFirst()
                .map(dot -> new CameraContextFocus(
                        "dot",
                        dot.layer(),
                        dot.targetType(),
                        dot.targetId(),
                        dot.title(),
                        dot.subtitle(),
                        firstActionType(dot),
                        firstActionHref(dot),
                        focusDisplayMode(dot),
                        dot.anchor(),
                        0,
                        dot.distanceMeters(),
                        dot.bearingDegrees(),
                        dot.relativeBearingDegrees(),
                        dot.relativeX(),
                        dot.relativeY(),
                        dot.altitudeDeltaMeters()))
                .orElse(null);
    }

    private String focusDisplayMode(CameraDot dot) {
        if (!"memories".equals(dot.layer())) {
            return "marker";
        }
        if (Boolean.TRUE.equals(dot.publicMemoryEligible()) && dot.anchor() != null && dot.anchor().arReady()) {
            return "ar_photo";
        }
        return "photo_hint";
    }

    private CameraDot matchingDot(CameraAdvisory advisory, List<CameraLayer> layers) {
        return layers.stream()
                .filter(layer -> layer.layer().equals(advisory.layer()))
                .flatMap(layer -> layer.dots().stream())
                .filter(dot -> dot.targetType().equals(advisory.targetType()))
                .filter(dot -> dot.targetId().equals(advisory.targetId()))
                .findFirst()
                .orElse(null);
    }

    private CameraAdvisory safetyAdvisory(CameraDot dot) {
        String actionType = firstActionType(dot);
        String severity = switch (actionType) {
            case "blocked" -> "critical";
            case "notify_guardian", "near_restricted_area" -> "warning";
            case "quiet_mode", "near_quiet_area" -> "info";
            default -> "";
        };
        if (severity.isEmpty()) {
            return null;
        }
        return new CameraAdvisory(
                severity,
                advisoryPriority(severity),
                advisoryDisplayMode(severity),
                dot.layer(),
                dot.targetType(),
                dot.targetId(),
                dot.title(),
                dot.subtitle(),
                actionType,
                firstActionHref(dot),
                dot.distanceMeters());
    }

    private CameraAdvisory anchorRefinementAdvisory(CameraLayer layer) {
        CameraDot dot = layer.dots().stream()
                .filter(this::needsAnchorRefinement)
                .min(Comparator.comparingDouble(CameraDot::distanceMeters)
                        .thenComparing(CameraDot::targetId))
                .orElse(null);
        if (dot == null) {
            return null;
        }
        CameraAction reviewAction = actionByType(dot, "review_anchor");
        return new CameraAdvisory(
                "warning",
                500,
                "hint",
                dot.layer(),
                dot.targetType(),
                dot.targetId(),
                "Anchor needs refinement",
                "Improve capture data before using this memory as an AR photo.",
                reviewAction == null ? "review_anchor" : reviewAction.type(),
                reviewAction == null ? "/memories/" + dot.targetId() : reviewAction.href(),
                dot.distanceMeters());
    }

    private boolean needsAnchorRefinement(CameraDot dot) {
        if (dot.anchor() == null) {
            return false;
        }
        if (dot.anchor().confidence() != null) {
            return !dot.anchor().confidence().recommendedActions().isEmpty();
        }
        return !dot.anchor().arReady();
    }

    private CameraAdvisory truncationAdvisory(CameraLayer layer) {
        return new CameraAdvisory(
                "info",
                100,
                "hint",
                layer.layer(),
                "",
                "",
                "More " + layer.layer() + " nearby",
                layer.totalAvailable() + " available, showing " + layer.count(),
                "expand_layer",
                "/camera/context?layers=" + layer.layer(),
                null);
    }

    private int advisoryPriority(String severity) {
        return switch (severity) {
            case "critical" -> 1000;
            case "warning" -> 700;
            case "info" -> 300;
            default -> 0;
        };
    }

    private String advisoryDisplayMode(String severity) {
        return switch (severity) {
            case "critical" -> "blocking_banner";
            case "warning" -> "banner";
            case "info" -> "hint";
            default -> "hidden";
        };
    }

    private double advisoryDistanceSortValue(CameraAdvisory advisory) {
        return advisory.distanceMeters() == null ? Double.MAX_VALUE : advisory.distanceMeters();
    }

    private String firstActionType(CameraDot dot) {
        CameraAction action = firstAction(dot);
        return action == null ? "" : action.type();
    }

    private String firstActionHref(CameraDot dot) {
        CameraAction action = firstAction(dot);
        return action == null ? "" : action.href();
    }

    private CameraAction firstAction(CameraDot dot) {
        return dot.actions() == null || dot.actions().isEmpty() ? null : dot.actions().getFirst();
    }

    private CameraAction actionByType(CameraDot dot, String type) {
        if (dot.actions() == null || dot.actions().isEmpty()) {
            return null;
        }
        return dot.actions().stream()
                .filter(action -> type.equals(action.type()))
                .findFirst()
                .orElse(null);
    }

    private String layerName(CameraOverlayProvider provider) {
        try {
            String layer = provider.layer();
            return layer == null || layer.isBlank() ? "unknown" : layer.trim();
        } catch (RuntimeException failure) {
            return "unknown";
        }
    }

    private record CameraContextBase(
            String viewerId,
            CameraTelemetry telemetry,
            CameraOverlayQuery query,
            List<String> requestedLayers,
            Instant generatedAt) {
    }
}
