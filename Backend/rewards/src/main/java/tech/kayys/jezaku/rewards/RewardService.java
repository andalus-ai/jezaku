package tech.kayys.jezaku.rewards;

import io.smallrye.mutiny.Uni;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.rewards.RewardDtos.BadgeCatalogResponse;
import tech.kayys.jezaku.rewards.RewardDtos.BadgeDefinitionResponse;
import tech.kayys.jezaku.rewards.RewardDtos.BadgeResponse;
import tech.kayys.jezaku.rewards.RewardDtos.LeaderboardEntry;
import tech.kayys.jezaku.rewards.RewardDtos.LeaderboardResponse;
import tech.kayys.jezaku.rewards.RewardDtos.RewardEventRequest;
import tech.kayys.jezaku.rewards.RewardDtos.RewardEventResponse;
import tech.kayys.jezaku.rewards.RewardDtos.RewardProfileResponse;
import tech.kayys.jezaku.rewards.RewardDtos.UserBadgesResponse;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import static tech.kayys.jezaku.taxonomy.JezakuTargetTypes.REWARD_SOURCE_TYPES;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class RewardService {
    private static final int XP_PER_LEVEL = 250;
    private static final Map<String, Integer> XP_BY_ACTION = Map.of(
            "memory_created", 40,
            "journey_completed", 120,
            "checkpoint_completed", 20,
            "event_checkin", 35,
            "helpful_comment", 15,
            "safety_report_resolved", 25,
            "daily_presence", 10);

    private final Map<String, RewardEventRecord> events = new ConcurrentHashMap<>();
    private final Map<String, BadgeDefinition> badgeCatalog = new LinkedHashMap<>();
    private final Map<String, BadgeRecord> badges = new ConcurrentHashMap<>();

    public RewardService() {
        seedCatalog();
        seedEvents();
    }

    public Uni<RewardEventResponse> recordEvent(RewardEventRequest request) {
        return Uni.createFrom().item(() -> {
            validateEvent(request);
            String userId = requireText(request.userId(), "userId");
            String action = normalizeAction(request.action());
            String sourceType = normalizeSourceType(request.sourceType());
            String sourceId = requireText(request.sourceId(), "sourceId");
            Instant occurredAt = request.occurredAt() == null ? Instant.now() : request.occurredAt();
            String key = eventKey(userId, action, sourceType, sourceId);
            RewardEventRecord existing = events.get(key);
            if (existing != null) {
                return toEventResponse(existing.withXpAwarded(0), List.of(), true);
            }
            RewardEventRecord record = new RewardEventRecord(
                    "reward_event_" + UUID.randomUUID(),
                    userId,
                    action,
                    sourceType,
                    sourceId,
                    XP_BY_ACTION.get(action),
                    occurredAt,
                    Instant.now());
            events.put(key, record);
            List<BadgeRecord> newlyAwarded = evaluateBadges(userId, record.createdAt());
            return toEventResponse(record, newlyAwarded, false);
        });
    }

    public Uni<RewardProfileResponse> profile(String userId) {
        return Uni.createFrom().item(() -> profileResponse(requireText(userId, "userId")));
    }

    public Uni<UserBadgesResponse> userBadges(String userId) {
        return Uni.createFrom().item(() -> {
            String normalizedUserId = requireText(userId, "userId");
            List<BadgeResponse> result = userBadgeRecords(normalizedUserId).stream()
                    .map(this::toBadgeResponse)
                    .toList();
            return new UserBadgesResponse(normalizedUserId, result.size(), result);
        });
    }

    public Uni<LeaderboardResponse> leaderboard(String scope, Integer limit) {
        return Uni.createFrom().item(() -> {
            String normalizedScope = normalizeScope(scope);
            int normalizedLimit = normalizeLimit(limit);
            Set<String> userIds = new LinkedHashSet<>();
            events.values().forEach(event -> userIds.add(event.userId()));
            List<LeaderboardEntry> entries = userIds.stream()
                    .map(userId -> leaderboardEntry(userId, normalizedScope))
                    .filter(entry -> entry.xp() > 0)
                    .sorted(Comparator.comparingInt(LeaderboardEntry::xp).reversed()
                            .thenComparing(LeaderboardEntry::userId))
                    .limit(normalizedLimit)
                    .toList();
            List<LeaderboardEntry> ranked = new ArrayList<>();
            for (int i = 0; i < entries.size(); i++) {
                LeaderboardEntry entry = entries.get(i);
                ranked.add(new LeaderboardEntry(i + 1, entry.userId(), entry.xp(), entry.level(), entry.badgeCount(), entry.streakDays()));
            }
            return new LeaderboardResponse(normalizedScope, ranked.size(), ranked);
        });
    }

    public Uni<BadgeCatalogResponse> badges() {
        return Uni.createFrom().item(() -> {
            List<BadgeDefinitionResponse> result = badgeCatalog.values().stream()
                    .sorted(Comparator.comparingInt(BadgeDefinition::priority))
                    .map(definition -> new BadgeDefinitionResponse(
                            definition.badgeId(),
                            definition.title(),
                            definition.description(),
                            definition.category(),
                            definition.priority()))
                    .toList();
            return new BadgeCatalogResponse(result.size(), result);
        });
    }

    private void seedCatalog() {
        addBadge("badge_first_memory", "First Memory", "Created a first public memory capture.", "memory", 10);
        addBadge("badge_anchor_loop", "Anchor Loop Finisher", "Completed the campus anchor loop journey.", "journey", 20);
        addBadge("badge_event_regular", "Event Regular", "Checked in to three spatial events.", "event", 30);
        addBadge("badge_week_streak", "Seven Day Signal", "Kept activity alive for seven consecutive days.", "streak", 40);
        addBadge("badge_helpful_neighbor", "Helpful Neighbor", "Left three helpful comments.", "social", 50);
        addBadge("badge_safety_helper", "Safety Helper", "Resolved a safety report.", "safety", 60);
    }

    private void seedEvents() {
        Instant now = Instant.now();
        seedEvent("user_current", "memory_created", "memory", "memory_seed_courtyard", now.minusSeconds(3_600));
        seedEvent("user_current", "event_checkin", "event", "event_seed_campus_walk", now.minusSeconds(2_800));
        seedEvent("user_current", "helpful_comment", "comment", "comment_seed_courtyard", now.minusSeconds(1_900));
        seedEvent("user_rooftop", "memory_created", "memory", "memory_seed_rooftop", now.minusSeconds(3_400));
        seedEvent("user_rooftop", "journey_completed", "journey", "journey_seed_anchor_loop", now.minusSeconds(1_500));
    }

    private void addBadge(String badgeId, String title, String description, String category, int priority) {
        badgeCatalog.put(badgeId, new BadgeDefinition(badgeId, title, description, category, priority));
    }

    private void seedEvent(String userId, String action, String sourceType, String sourceId, Instant occurredAt) {
        RewardEventRecord record = new RewardEventRecord(
                "reward_event_seed_" + sourceId,
                userId,
                action,
                sourceType,
                sourceId,
                XP_BY_ACTION.get(action),
                occurredAt,
                occurredAt);
        events.put(eventKey(userId, action, sourceType, sourceId), record);
        evaluateBadges(userId, occurredAt);
    }

    private void validateEvent(RewardEventRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.userId(), "userId");
        normalizeAction(request.action());
        normalizeSourceType(request.sourceType());
        requireText(request.sourceId(), "sourceId");
    }

    private RewardProfileResponse profileResponse(String userId) {
        int totalXp = totalXp(userId);
        List<BadgeResponse> badgeResponses = userBadgeRecords(userId).stream()
                .map(this::toBadgeResponse)
                .toList();
        List<RewardEventResponse> recentEvents = userEvents(userId).stream()
                .sorted(Comparator.comparing(RewardEventRecord::occurredAt).reversed())
                .limit(10)
                .map(event -> toEventResponse(event, List.of(), false))
                .toList();
        return new RewardProfileResponse(
                userId,
                totalXp,
                level(totalXp),
                totalXp % XP_PER_LEVEL,
                XP_PER_LEVEL,
                streakDays(userId),
                lastActivityDate(userId),
                badgeResponses.size(),
                badgeResponses,
                recentEvents);
    }

    private LeaderboardEntry leaderboardEntry(String userId, String scope) {
        int xp = "weekly".equals(scope) ? weeklyXp(userId) : totalXp(userId);
        return new LeaderboardEntry(0, userId, xp, level(totalXp(userId)), userBadgeRecords(userId).size(), streakDays(userId));
    }

    private List<BadgeRecord> evaluateBadges(String userId, Instant earnedAt) {
        List<BadgeRecord> awarded = new ArrayList<>();
        if (actionCount(userId, "memory_created") >= 1) {
            awarded.add(awardIfAbsent(userId, "badge_first_memory", earnedAt));
        }
        if (hasEvent(userId, "journey_completed", "journey_seed_anchor_loop")) {
            awarded.add(awardIfAbsent(userId, "badge_anchor_loop", earnedAt));
        }
        if (actionCount(userId, "event_checkin") >= 3) {
            awarded.add(awardIfAbsent(userId, "badge_event_regular", earnedAt));
        }
        if (streakDays(userId) >= 7) {
            awarded.add(awardIfAbsent(userId, "badge_week_streak", earnedAt));
        }
        if (actionCount(userId, "helpful_comment") >= 3) {
            awarded.add(awardIfAbsent(userId, "badge_helpful_neighbor", earnedAt));
        }
        if (actionCount(userId, "safety_report_resolved") >= 1) {
            awarded.add(awardIfAbsent(userId, "badge_safety_helper", earnedAt));
        }
        return awarded.stream()
                .filter(badge -> badge.earnedAt().equals(earnedAt))
                .toList();
    }

    private BadgeRecord awardIfAbsent(String userId, String badgeId, Instant earnedAt) {
        String key = badgeKey(userId, badgeId);
        BadgeRecord existing = badges.get(key);
        if (existing != null) {
            return existing;
        }
        BadgeDefinition definition = badgeCatalog.get(badgeId);
        BadgeRecord record = new BadgeRecord(
                userId,
                definition.badgeId(),
                definition.title(),
                definition.description(),
                definition.category(),
                earnedAt);
        badges.put(key, record);
        return record;
    }

    private RewardEventResponse toEventResponse(RewardEventRecord event, List<BadgeRecord> badgesAwarded, boolean duplicate) {
        int totalXp = totalXp(event.userId());
        return new RewardEventResponse(
                event.eventId(),
                event.userId(),
                event.action(),
                event.sourceType(),
                event.sourceId(),
                event.xpAwarded(),
                totalXp,
                level(totalXp),
                badgesAwarded.stream().map(this::toBadgeResponse).toList(),
                duplicate,
                event.occurredAt(),
                event.createdAt());
    }

    private BadgeResponse toBadgeResponse(BadgeRecord badge) {
        return new BadgeResponse(
                badge.userId(),
                badge.badgeId(),
                badge.title(),
                badge.description(),
                badge.category(),
                badge.earnedAt());
    }

    private List<RewardEventRecord> userEvents(String userId) {
        return events.values().stream()
                .filter(event -> event.userId().equals(userId))
                .toList();
    }

    private List<BadgeRecord> userBadgeRecords(String userId) {
        return badges.values().stream()
                .filter(badge -> badge.userId().equals(userId))
                .sorted(Comparator.comparing(BadgeRecord::earnedAt).reversed())
                .toList();
    }

    private int totalXp(String userId) {
        return userEvents(userId).stream().mapToInt(RewardEventRecord::xpAwarded).sum();
    }

    private int weeklyXp(String userId) {
        Instant cutoff = Instant.now().minus(7, ChronoUnit.DAYS);
        return userEvents(userId).stream()
                .filter(event -> !event.occurredAt().isBefore(cutoff))
                .mapToInt(RewardEventRecord::xpAwarded)
                .sum();
    }

    private int level(int totalXp) {
        return (totalXp / XP_PER_LEVEL) + 1;
    }

    private int actionCount(String userId, String action) {
        return (int) userEvents(userId).stream()
                .filter(event -> event.action().equals(action))
                .count();
    }

    private boolean hasEvent(String userId, String action, String sourceId) {
        return userEvents(userId).stream()
                .anyMatch(event -> event.action().equals(action) && event.sourceId().equals(sourceId));
    }

    private int streakDays(String userId) {
        List<LocalDate> dates = userEvents(userId).stream()
                .map(event -> event.occurredAt().atZone(ZoneOffset.UTC).toLocalDate())
                .distinct()
                .sorted(Comparator.reverseOrder())
                .toList();
        if (dates.isEmpty()) {
            return 0;
        }
        int streak = 1;
        LocalDate expected = dates.get(0).minusDays(1);
        for (int i = 1; i < dates.size(); i++) {
            LocalDate date = dates.get(i);
            if (date.equals(expected)) {
                streak++;
                expected = expected.minusDays(1);
            } else if (date.isBefore(expected)) {
                break;
            }
        }
        return streak;
    }

    private LocalDate lastActivityDate(String userId) {
        return userEvents(userId).stream()
                .map(RewardEventRecord::occurredAt)
                .max(Instant::compareTo)
                .map(instant -> instant.atZone(ZoneOffset.UTC).toLocalDate())
                .orElse(null);
    }

    private String normalizeAction(String value) {
        return requireChoice(value, XP_BY_ACTION.keySet(), "action");
    }

    private String normalizeSourceType(String value) {
        return requireChoice(value, REWARD_SOURCE_TYPES, "sourceType");
    }

    private String normalizeScope(String value) {
        return optionalChoice(value, "global", Set.of("global", "weekly"), "scope", "scope must be global or weekly");
    }

    private int normalizeLimit(Integer limit) {
        return normalizeBoundedInt(limit, 20, 1, 100, "limit");
    }

    private String eventKey(String userId, String action, String sourceType, String sourceId) {
        return userId + "|" + action + "|" + sourceType + "|" + sourceId;
    }

    private String badgeKey(String userId, String badgeId) {
        return userId + "|" + badgeId;
    }

    private record RewardEventRecord(
            String eventId,
            String userId,
            String action,
            String sourceType,
            String sourceId,
            int xpAwarded,
            Instant occurredAt,
            Instant createdAt) {
        private RewardEventRecord withXpAwarded(int xpAwarded) {
            return new RewardEventRecord(eventId, userId, action, sourceType, sourceId, xpAwarded, occurredAt, createdAt);
        }
    }

    private record BadgeDefinition(
            String badgeId,
            String title,
            String description,
            String category,
            int priority) {
    }

    private record BadgeRecord(
            String userId,
            String badgeId,
            String title,
            String description,
            String category,
            Instant earnedAt) {
    }
}
