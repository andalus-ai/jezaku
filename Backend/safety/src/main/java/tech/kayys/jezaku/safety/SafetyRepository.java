package tech.kayys.jezaku.safety;

import java.util.List;

interface SafetyRepository {
    void saveReport(ReportRecord report);

    ReportRecord findReportById(String reportId);

    List<ReportRecord> findAllReports();

    void saveReviewEvent(SafetyReviewEvent event);

    List<SafetyReviewEvent> findReviewEventsByReportId(String reportId);

    void saveZone(SafetyZoneRecord zone);

    SafetyZoneRecord findZoneById(String zoneId);

    List<SafetyZoneRecord> findAllZones();

    boolean deleteZoneById(String zoneId);
}
