package tech.kayys.jezaku.camera;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import tech.kayys.jezaku.camera.CameraDotProjection.Projection;
import tech.kayys.jezaku.camera.CameraDtos.CameraAction;
import tech.kayys.jezaku.camera.CameraDtos.CameraDot;
import tech.kayys.jezaku.camera.CameraDtos.CameraLayer;
import tech.kayys.jezaku.camera.CameraDtos.GeoPoint;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;

@ApplicationScoped
public class SeedSafetyOverlayProvider implements CameraOverlayProvider {
    @Override
    public String layer() {
        return "safety";
    }

    @Override
    public Uni<CameraLayer> layer(CameraOverlayQuery query) {
        return Uni.createFrom().item(() -> {
            if (query.viewerId().isEmpty()) {
                List<CameraDot> dots = List.of();
                return new CameraLayer(
                        layer(),
                        "ready",
                        "",
                        CameraLayerSources.seed(query.now()),
                        0,
                        0,
                        false,
                        CameraLayerSummaries.from(dots),
                        dots);
            }
            List<CameraDot> available = seeds(query.now()).stream()
                    .filter(SafetyZoneSeed::active)
                    .filter(seed -> seed.userId().equals(query.viewerId()))
                    .map(seed -> new Candidate(seed, toDot(seed, query)))
                    .filter(candidate -> intersectsRadius(candidate.dot(), candidate.seed(), query.radiusMeters()))
                    .sorted(Comparator.comparingDouble(candidate -> candidate.dot().distanceMeters()))
                    .map(Candidate::dot)
                    .toList();
            List<CameraDot> dots = available.stream()
                    .limit(query.limitPerLayer())
                    .toList();
            return new CameraLayer(layer(), "ready", "", CameraLayerSources.seed(query.now()), dots.size(),
                    available.size(), available.size() > dots.size(),
                    CameraLayerSummaries.from(dots), dots);
        });
    }

    private CameraDot toDot(SafetyZoneSeed seed, CameraOverlayQuery query) {
        Projection projection = CameraDotProjection.from(
                query.origin(),
                seed.center(),
                query.orientationDegrees(),
                query.radiusMeters());
        ZoneDecision decision = decision(seed, projection.distanceMeters());
        long ageSeconds = secondsSince(seed.updatedAt(), query.now());
        return new CameraDot(
                layer(),
                "safety_zone",
                seed.zoneId(),
                seed.guardianId(),
                null,
                "seed",
                "guardian",
                null,
                ageSeconds,
                null,
                CameraDotPresentation.distanceBucket(projection.distanceRatio()),
                CameraDotPresentation.freshnessState(ageSeconds, null),
                seed.name(),
                decision.action(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                seed.center(),
                null,
                null,
                projection.distanceMeters(),
                projection.distanceRatio(),
                projection.bearingDegrees(),
                projection.relativeBearingDegrees(),
                projection.relativeX(),
                projection.relativeY(),
                projection.altitudeDeltaMeters(),
                seed.updatedAt(),
                List.of(new CameraAction(
                        decision.action(),
                        decision.label(),
                        "/safety/zones/users/" + seed.userId())));
    }

    private boolean intersectsRadius(CameraDot dot, SafetyZoneSeed seed, double radiusMeters) {
        return dot.distanceMeters() <= radiusMeters + seed.radiusMeters();
    }

    private ZoneDecision decision(SafetyZoneSeed seed, double distanceMeters) {
        boolean inside = distanceMeters <= seed.radiusMeters();
        return switch (seed.zoneType()) {
            case "safe_area" -> inside
                    ? new ZoneDecision("inside_safe_area", "Inside safe area")
                    : new ZoneDecision("notify_guardian", "Notify guardian");
            case "restricted_area" -> inside
                    ? new ZoneDecision("blocked", "Restricted area")
                    : new ZoneDecision("near_restricted_area", "Near restricted area");
            case "quiet_area" -> inside
                    ? new ZoneDecision("quiet_mode", "Quiet mode")
                    : new ZoneDecision("near_quiet_area", "Near quiet area");
            default -> new ZoneDecision("zone_nearby", "Review zone");
        };
    }

    private long secondsSince(Instant value, Instant now) {
        return Math.max(0, Duration.between(value, now).toSeconds());
    }

    private List<SafetyZoneSeed> seeds(Instant now) {
        return List.of(
                new SafetyZoneSeed(
                        "zone_seed_campus_safe",
                        "guardian_1",
                        "teen_explorer",
                        "Campus Safe Area",
                        new GeoPoint(-6.890620, 107.610790, 742.0),
                        100.0,
                        "safe_area",
                        true,
                        now.minusSeconds(1_800)),
                new SafetyZoneSeed(
                        "zone_seed_lab_restricted",
                        "guardian_1",
                        "teen_explorer",
                        "Rooftop Lab Restriction",
                        new GeoPoint(-6.890580, 107.610970, 746.4),
                        30.0,
                        "restricted_area",
                        true,
                        now.minusSeconds(1_700)));
    }

    private record Candidate(SafetyZoneSeed seed, CameraDot dot) {
    }

    private record ZoneDecision(String action, String label) {
    }

    private record SafetyZoneSeed(
            String zoneId,
            String guardianId,
            String userId,
            String name,
            GeoPoint center,
            double radiusMeters,
            String zoneType,
            boolean active,
            Instant updatedAt) {
    }
}
