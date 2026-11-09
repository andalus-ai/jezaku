package tech.kayys.jezaku.safety;

import jakarta.enterprise.context.ApplicationScoped;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class InMemorySafetyRepository implements SafetyRepository {
    private final Map<String, ReportRecord> reports = new ConcurrentHashMap<>();
    private final Map<String, List<SafetyReviewEvent>> reviewEvents = new ConcurrentHashMap<>();
    private final Map<String, SafetyZoneRecord> zones = new ConcurrentHashMap<>();

    @Override
    public void saveReport(ReportRecord report) {
        reports.put(report.reportId(), report);
    }

    @Override
    public ReportRecord findReportById(String reportId) {
        return reports.get(reportId);
    }

    @Override
    public List<ReportRecord> findAllReports() {
        return List.copyOf(reports.values());
    }

    @Override
    public void saveReviewEvent(SafetyReviewEvent event) {
        reviewEvents.compute(event.reportId(), (reportId, events) -> {
            List<SafetyReviewEvent> updated = new ArrayList<>();
            if (events != null) {
                updated.addAll(events);
            }
            updated.add(event);
            return List.copyOf(updated);
        });
    }

    @Override
    public List<SafetyReviewEvent> findReviewEventsByReportId(String reportId) {
        return List.copyOf(reviewEvents.getOrDefault(reportId, List.of()));
    }

    @Override
    public void saveZone(SafetyZoneRecord zone) {
        zones.put(zone.zoneId(), zone);
    }

    @Override
    public SafetyZoneRecord findZoneById(String zoneId) {
        return zones.get(zoneId);
    }

    @Override
    public List<SafetyZoneRecord> findAllZones() {
        return List.copyOf(zones.values());
    }

    @Override
    public boolean deleteZoneById(String zoneId) {
        return zones.remove(zoneId) != null;
    }
}
