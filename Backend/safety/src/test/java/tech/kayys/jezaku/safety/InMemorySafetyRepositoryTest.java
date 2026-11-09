package tech.kayys.jezaku.safety;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.safety.SafetyDtos.GeoPoint;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InMemorySafetyRepositoryTest {
    @Test
    void savesFindsListsAndDeletesSafetyRecords() {
        InMemorySafetyRepository repository = new InMemorySafetyRepository();
        Instant createdAt = Instant.parse("2026-05-30T00:00:00Z");
        Instant updatedAt = Instant.parse("2026-05-30T00:05:00Z");
        ReportRecord report = new ReportRecord(
                "report_repo",
                "user_repo",
                "media",
                "media_repo",
                "owner_repo",
                "inappropriate_media",
                "Needs review.",
                List.of("media_repo"),
                new GeoPoint(-6.890620, 107.610790, 742.0),
                "open",
                "none",
                "",
                "",
                createdAt,
                updatedAt);
        SafetyReviewEvent event = new SafetyReviewEvent(
                "review_repo",
                "report_repo",
                "moderator_repo",
                "open",
                "resolved",
                "none",
                "hide_content",
                "Hidden after review.",
                updatedAt);
        SafetyZoneRecord zone = new SafetyZoneRecord(
                "zone_repo",
                "guardian_repo",
                "child_repo",
                "Quiet Library",
                new GeoPoint(-6.890620, 107.610790, null),
                75.0,
                "quiet_area",
                true,
                createdAt,
                updatedAt);

        repository.saveReport(report);
        repository.saveReviewEvent(event);
        repository.saveZone(zone);

        assertEquals(report, repository.findReportById("report_repo"));
        assertEquals(List.of(report), repository.findAllReports());
        assertEquals(List.of(event), repository.findReviewEventsByReportId("report_repo"));
        assertEquals(zone, repository.findZoneById("zone_repo"));
        assertEquals(List.of(zone), repository.findAllZones());
        assertTrue(repository.deleteZoneById("zone_repo"));
        assertEquals(List.of(), repository.findAllZones());
    }
}
