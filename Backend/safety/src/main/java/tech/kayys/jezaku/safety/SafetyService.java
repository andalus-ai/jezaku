package tech.kayys.jezaku.safety;

import io.smallrye.mutiny.Uni;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.safety.SafetyDtos.GeoPoint;
import tech.kayys.jezaku.safety.SafetyDtos.ReportCreateRequest;
import tech.kayys.jezaku.safety.SafetyDtos.ReportListResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportQueueBucket;
import tech.kayys.jezaku.safety.SafetyDtos.ReportQueueSummaryResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportReviewEventResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportReviewHistoryResponse;
import tech.kayys.jezaku.safety.SafetyDtos.ReportReviewRequest;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneCheckRequest;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneCheckResponse;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneCreateRequest;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneHit;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneListResponse;
import tech.kayys.jezaku.safety.SafetyDtos.SafetyZoneResponse;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.UUID;
import java.util.function.Function;

import static tech.kayys.jezaku.taxonomy.JezakuTargetTypes.REPORTABLE_TARGET_TYPES;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.SAFETY_REPORT_STATUSES;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.SAFETY_REVIEW_ACTIONS;
import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.SAFETY_ZONE_TYPES;
import static tech.kayys.jezaku.geo.GeoMath.distanceMeters;
import static tech.kayys.jezaku.geo.GeoMath.round2;
import static tech.kayys.jezaku.geo.GeoMath.validateLatLng;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedDouble;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class SafetyService {
    private static final Set<String> REPORT_REASONS = Set.of(
            "harassment",
            "unsafe_location",
            "inappropriate_media",
            "underage_risk",
            "spam",
            "other");
    private static final double MIN_ZONE_RADIUS_METERS = 10.0;
    private static final double MAX_ZONE_RADIUS_METERS = 5_000.0;

    @Inject
    SafetyRepository repository;

    @PostConstruct
    void initialize() {
        seed();
    }

    public Uni<ReportResponse> createReport(ReportCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateCreateReport(request);
            Instant now = Instant.now();
            ReportRecord record = new ReportRecord(
                    "report_" + UUID.randomUUID(),
                    requireText(request.reporterId(), "reporterId"),
                    normalizeChoice(request.targetType(), REPORTABLE_TARGET_TYPES, "targetType"),
                    requireText(request.targetId(), "targetId"),
                    optionalTrim(request.targetUserId(), ""),
                    normalizeChoice(request.reason(), REPORT_REASONS, "reason"),
                    normalizeDetails(request.details()),
                    normalizeEvidence(request.evidenceMediaIds()),
                    request.position(),
                    "open",
                    "none",
                    "",
                    "",
                    now,
                    now);
            repository.saveReport(record);
            return toResponse(record);
        });
    }

    public Uni<ReportListResponse> reports(String status, String targetType, String reason, String targetUserId) {
        return Uni.createFrom().item(() -> {
            String normalizedStatus = normalizeOptionalChoice(status, SAFETY_REPORT_STATUSES, "status");
            String normalizedTargetType = normalizeOptionalChoice(targetType, REPORTABLE_TARGET_TYPES, "targetType");
            String normalizedReason = normalizeOptionalChoice(reason, REPORT_REASONS, "reason");
            String normalizedTargetUserId = optionalTrim(targetUserId, "");
            String filter = normalizedStatus;
            List<ReportResponse> result = repository.findAllReports().stream()
                    .filter(report -> matches(filter, report.status()))
                    .filter(report -> matches(normalizedTargetType, report.targetType()))
                    .filter(report -> matches(normalizedReason, report.reason()))
                    .filter(report -> matches(normalizedTargetUserId, report.targetUserId()))
                    .sorted(Comparator.comparing(ReportRecord::updatedAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new ReportListResponse(filter.isEmpty() ? "all" : filter, result.size(), result);
        });
    }

    public Uni<ReportQueueSummaryResponse> reportSummary() {
        return Uni.createFrom().item(() -> {
            List<ReportRecord> reportRecords = repository.findAllReports();
            return new ReportQueueSummaryResponse(
                    reportRecords.size(),
                    bucketBy(reportRecords, ReportRecord::status),
                    bucketBy(reportRecords, ReportRecord::targetType),
                    bucketBy(reportRecords, ReportRecord::reason),
                    bucketBy(reportRecords, ReportRecord::action));
        });
    }

    public Uni<ReportResponse> report(String reportId) {
        return Uni.createFrom().item(() -> toResponse(requireReport(reportId)));
    }

    public Uni<ReportResponse> review(String reportId, ReportReviewRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            ReportRecord report = requireReport(reportId);
            String reviewerId = requireText(request.reviewerId(), "reviewerId");
            String status = normalizeChoice(request.status(), SAFETY_REPORT_STATUSES, "status");
            String action = normalizeChoice(request.action(), SAFETY_REVIEW_ACTIONS, "action");
            String notes = normalizeDetails(request.notes());
            Instant now = Instant.now();
            ReportRecord reviewed = report.withReview(status, action, reviewerId, notes, now);
            repository.saveReport(reviewed);
            repository.saveReviewEvent(new SafetyReviewEvent(
                    "safety_review_" + UUID.randomUUID(),
                    report.reportId(),
                    reviewerId,
                    report.status(),
                    reviewed.status(),
                    report.action(),
                    reviewed.action(),
                    notes,
                    now));
            return toResponse(reviewed);
        });
    }

    public Uni<ReportReviewHistoryResponse> reviewHistory(String reportId, String reviewerId) {
        return Uni.createFrom().item(() -> {
            ReportRecord report = requireReport(reportId);
            requireText(reviewerId, "reviewerId");
            List<ReportReviewEventResponse> events = repository.findReviewEventsByReportId(report.reportId()).stream()
                    .sorted(Comparator.comparing(SafetyReviewEvent::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new ReportReviewHistoryResponse(report.reportId(), events.size(), events);
        });
    }

    public Uni<SafetyZoneResponse> createZone(SafetyZoneCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateCreateZone(request);
            Instant now = Instant.now();
            SafetyZoneRecord record = new SafetyZoneRecord(
                    "zone_" + UUID.randomUUID(),
                    requireText(request.guardianId(), "guardianId"),
                    requireText(request.userId(), "userId"),
                    optionalTrim(request.name(), "Safety Zone"),
                    request.center(),
                    normalizeRadius(request.radiusMeters()),
                    normalizeChoice(request.zoneType(), SAFETY_ZONE_TYPES, "zoneType"),
                    request.active() == null || request.active(),
                    now,
                    now);
            repository.saveZone(record);
            return toResponse(record);
        });
    }

    public Uni<SafetyZoneListResponse> userZones(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<SafetyZoneResponse> result = repository.findAllZones().stream()
                    .filter(zone -> zone.userId().equals(normalizedUserId))
                    .sorted(Comparator.comparing(SafetyZoneRecord::createdAt).reversed())
                    .map(this::toResponse)
                    .toList();
            return new SafetyZoneListResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<SafetyZoneCheckResponse> checkZone(SafetyZoneCheckRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String userId = requireText(request.userId(), "userId");
            if (request.position() == null) {
                throw new BadRequestException("position is required");
            }
            validateLatLng(request.position().latitude(), request.position().longitude());
            List<SafetyZoneHit> hits = repository.findAllZones().stream()
                    .filter(zone -> zone.userId().equals(userId))
                    .filter(SafetyZoneRecord::active)
                    .map(zone -> evaluate(zone, request.position()))
                    .filter(hit -> !"allowed".equals(hit.action()))
                    .sorted(Comparator.comparingDouble(SafetyZoneHit::distanceMeters))
                    .toList();
            return new SafetyZoneCheckResponse(userId, request.position(), decision(hits), hits.size(), hits);
        });
    }

    public Uni<Void> deleteZone(String zoneId, String guardianId) {
        return Uni.createFrom().item(() -> {
            SafetyZoneRecord zone = requireZone(zoneId);
            String normalizedGuardianId = requireText(guardianId, "guardianId");
            if (!zone.guardianId().equals(normalizedGuardianId)) {
                throw new ForbiddenException("Safety zone guardian mismatch");
            }
            repository.deleteZoneById(zone.zoneId());
            return null;
        });
    }

    private void seed() {
        Instant now = Instant.now();
        repository.saveReport(new ReportRecord(
                "report_seed_media",
                "user_current",
                "media",
                "media_seed_pending",
                "user_rooftop",
                "inappropriate_media",
                "Photo needs review before public discovery.",
                List.of("media_seed_pending"),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                "open",
                "none",
                "",
                "",
                now.minusSeconds(1_200),
                now.minusSeconds(1_000)));
        repository.saveReport(new ReportRecord(
                "report_seed_presence",
                "guardian_1",
                "presence",
                "user_stale",
                "teen_explorer",
                "unsafe_location",
                "Stale location signal outside normal area.",
                List.of(),
                new GeoPoint(-6.893100, 107.613300, 739.2),
                "resolved",
                "notify_guardian",
                "moderator_1",
                "Guardian notified.",
                now.minusSeconds(900),
                now.minusSeconds(800)));
        repository.saveReviewEvent(new SafetyReviewEvent(
                "safety_review_seed_presence",
                "report_seed_presence",
                "moderator_1",
                "open",
                "resolved",
                "none",
                "notify_guardian",
                "Guardian notified.",
                now.minusSeconds(800)));
        repository.saveZone(new SafetyZoneRecord(
                "zone_seed_campus_safe",
                "guardian_1",
                "teen_explorer",
                "Campus Safe Area",
                new GeoPoint(-6.890620, 107.610790, 742.0),
                100.0,
                "safe_area",
                true,
                now.minusSeconds(2_000),
                now.minusSeconds(1_800)));
        repository.saveZone(new SafetyZoneRecord(
                "zone_seed_lab_restricted",
                "guardian_1",
                "teen_explorer",
                "Rooftop Lab Restriction",
                new GeoPoint(-6.890580, 107.610970, 746.4),
                30.0,
                "restricted_area",
                true,
                now.minusSeconds(1_900),
                now.minusSeconds(1_700)));
    }

    private void validateCreateReport(ReportCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.reporterId(), "reporterId");
        normalizeChoice(request.targetType(), REPORTABLE_TARGET_TYPES, "targetType");
        requireText(request.targetId(), "targetId");
        normalizeChoice(request.reason(), REPORT_REASONS, "reason");
        normalizeDetails(request.details());
        if (request.position() != null) {
            validateLatLng(request.position().latitude(), request.position().longitude());
        }
    }

    private void validateCreateZone(SafetyZoneCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.guardianId(), "guardianId");
        requireText(request.userId(), "userId");
        if (request.center() == null) {
            throw new BadRequestException("center is required");
        }
        validateLatLng(request.center().latitude(), request.center().longitude());
        normalizeRadius(request.radiusMeters());
        normalizeChoice(request.zoneType(), SAFETY_ZONE_TYPES, "zoneType");
    }

    private ReportRecord requireReport(String reportId) {
        String normalizedReportId = requireText(reportId, "reportId");
        ReportRecord report = repository.findReportById(normalizedReportId);
        if (report == null) {
            throw new NotFoundException("Report not found: " + normalizedReportId);
        }
        return report;
    }

    private SafetyZoneRecord requireZone(String zoneId) {
        String normalizedZoneId = requireText(zoneId, "zoneId");
        SafetyZoneRecord zone = repository.findZoneById(normalizedZoneId);
        if (zone == null) {
            throw new NotFoundException("Safety zone not found: " + normalizedZoneId);
        }
        return zone;
    }

    private SafetyZoneHit evaluate(SafetyZoneRecord zone, GeoPoint position) {
        double distance = distanceMeters(position.latitude(), position.longitude(),
                zone.center().latitude(), zone.center().longitude());
        boolean inside = distance <= zone.radiusMeters();
        String action = switch (zone.zoneType()) {
            case "safe_area" -> inside ? "allowed" : "notify_guardian";
            case "restricted_area" -> inside ? "blocked" : "allowed";
            case "quiet_area" -> inside ? "quiet_mode" : "allowed";
            default -> "allowed";
        };
        return new SafetyZoneHit(
                zone.zoneId(),
                zone.name(),
                zone.zoneType(),
                round2(zone.radiusMeters()),
                round2(distance),
                inside,
                action);
    }

    private String decision(List<SafetyZoneHit> hits) {
        if (hits.stream().anyMatch(hit -> "blocked".equals(hit.action()))) {
            return "blocked";
        }
        if (hits.stream().anyMatch(hit -> "notify_guardian".equals(hit.action()))) {
            return "notify_guardian";
        }
        if (hits.stream().anyMatch(hit -> "quiet_mode".equals(hit.action()))) {
            return "quiet_mode";
        }
        return "allowed";
    }

    private ReportResponse toResponse(ReportRecord report) {
        return new ReportResponse(
                report.reportId(),
                report.reporterId(),
                report.targetType(),
                report.targetId(),
                report.targetUserId(),
                report.reason(),
                report.details(),
                report.evidenceMediaIds(),
                report.position(),
                report.status(),
                report.action(),
                report.reviewerId(),
                report.reviewNotes(),
                report.createdAt(),
                report.updatedAt());
    }

    private ReportReviewEventResponse toResponse(SafetyReviewEvent event) {
        return new ReportReviewEventResponse(
                event.eventId(),
                event.reportId(),
                event.reviewerId(),
                event.previousStatus(),
                event.nextStatus(),
                event.previousAction(),
                event.nextAction(),
                event.notes(),
                event.createdAt());
    }

    private SafetyZoneResponse toResponse(SafetyZoneRecord zone) {
        return new SafetyZoneResponse(
                zone.zoneId(),
                zone.guardianId(),
                zone.userId(),
                zone.name(),
                zone.center(),
                round2(zone.radiusMeters()),
                zone.zoneType(),
                zone.active(),
                zone.createdAt(),
                zone.updatedAt());
    }

    private String normalizeChoice(String value, Set<String> allowed, String field) {
        return requireChoice(value, allowed, field);
    }

    private String normalizeOptionalChoice(String value, Set<String> allowed, String field) {
        String normalized = optionalTrim(value, "");
        return normalized.isEmpty() ? "" : normalizeChoice(normalized, allowed, field);
    }

    private boolean matches(String filter, String value) {
        return filter.isEmpty() || filter.equals(value);
    }

    private List<ReportQueueBucket> bucketBy(
            List<ReportRecord> reportRecords,
            Function<ReportRecord, String> classifier) {
        Map<String, Integer> counts = new TreeMap<>();
        reportRecords.forEach(report -> counts.merge(classifier.apply(report), 1, Integer::sum));
        return counts.entrySet().stream()
                .map(entry -> new ReportQueueBucket(entry.getKey(), entry.getValue()))
                .toList();
    }

    private double normalizeRadius(double radiusMeters) {
        return round2(normalizeBoundedDouble(radiusMeters, MIN_ZONE_RADIUS_METERS, MAX_ZONE_RADIUS_METERS,
                "radiusMeters"));
    }

    private List<String> normalizeEvidence(List<String> values) {
        return normalizeUniqueStrings(values);
    }

    private String normalizeDetails(String value) {
        return optionalTextMaxLength(value, "", "details", 1_000);
    }
}
