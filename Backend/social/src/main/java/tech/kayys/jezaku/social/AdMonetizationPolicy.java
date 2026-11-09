package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAdBudgetPacing;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;

final class AdMonetizationPolicy {
    static final Set<String> CREATIVE_REVIEW_STATUSES = Set.of(
            "pending_review",
            "approved",
            "rejected");

    private static final Set<String> OBJECTIVES = Set.of("awareness", "traffic", "engagement", "conversion");
    private static final Set<String> PLACEMENTS = Set.of("feed", "camera", "minimap", "story");
    private static final Set<String> EVENT_TYPES = Set.of("impression", "click", "conversion");
    private static final long IMPRESSION_COST_CENTS = 1L;
    private static final long CLICK_COST_CENTS = 25L;
    private static final long CONVERSION_COST_CENTS = 100L;

    private AdMonetizationPolicy() {
    }

    static String initialCreativeReviewStatus(String creativeContentId) {
        return creativeContentId == null || creativeContentId.isBlank() ? "approved" : "pending_review";
    }

    static String creativeReviewStatus(String status) {
        return optionalChoice(status, "pending_review", CREATIVE_REVIEW_STATUSES,
                "status", "status must be pending_review, approved, or rejected");
    }

    static String objective(String objective) {
        return optionalChoice(objective, "awareness", OBJECTIVES,
                "objective", "objective must be awareness, traffic, engagement, or conversion");
    }

    static String placement(String placement) {
        return optionalChoice(placement, "feed", PLACEMENTS,
                "placement", "placement must be feed, camera, minimap, or story");
    }

    static String eventType(String eventType) {
        return optionalChoice(eventType, "impression", EVENT_TYPES,
                "eventType", "eventType must be impression, click, or conversion");
    }

    static boolean creativeApproved(SocialAdCampaignRecord campaign) {
        return "approved".equals(campaign.creativeReviewStatus());
    }

    static long eventCostCents(String eventType) {
        return switch (eventType) {
            case "click" -> CLICK_COST_CENTS;
            case "conversion" -> CONVERSION_COST_CENTS;
            default -> IMPRESSION_COST_CENTS;
        };
    }

    static long campaignSpentCents(List<SocialAdEventRecord> events) {
        return events.stream()
                .mapToLong(event -> eventCostCents(event.eventType()))
                .sum();
    }

    static long campaignRemainingBudgetCents(SocialAdCampaignRecord campaign, long spentCents) {
        return Math.max(0L, campaign.budgetCents() - spentCents);
    }

    static SocialAdBudgetPacing budgetPacing(
            SocialAdCampaignRecord campaign,
            long spentCents,
            long remainingBudgetCents,
            Instant now) {
        long durationSeconds = Math.max(1L, campaign.endsAt().getEpochSecond() - campaign.startsAt().getEpochSecond());
        long elapsedSeconds;
        if (now.isBefore(campaign.startsAt())) {
            elapsedSeconds = 0L;
        } else if (!campaign.endsAt().isAfter(now)) {
            elapsedSeconds = durationSeconds;
        } else {
            elapsedSeconds = Math.max(0L, now.getEpochSecond() - campaign.startsAt().getEpochSecond());
        }
        double elapsedRatio = Math.min(1.0, Math.max(0.0, (double) elapsedSeconds / durationSeconds));
        double spendRatio = campaign.budgetCents() == 0 ? 0.0 : (double) spentCents / campaign.budgetCents();
        long expectedSpentCents = Math.round(campaign.budgetCents() * elapsedRatio);
        long projectedSpendCents = elapsedSeconds == 0
                ? spentCents
                : Math.round(spentCents / Math.max(elapsedRatio, 0.000001));
        long dailyBudgetCents = Math.max(1L,
                (long) Math.ceil(campaign.budgetCents() / Math.max(durationSeconds / 86_400.0, 1.0 / 86_400.0)));
        long secondsRemaining = now.isBefore(campaign.endsAt())
                ? Math.max(0L, campaign.endsAt().getEpochSecond() - now.getEpochSecond())
                : 0L;
        return new SocialAdBudgetPacing(
                budgetPacingStatus(campaign, spentCents, remainingBudgetCents, expectedSpentCents, now),
                dailyBudgetCents,
                expectedSpentCents,
                projectedSpendCents,
                remainingBudgetCents,
                secondsRemaining,
                elapsedRatio,
                spendRatio);
    }

    private static String budgetPacingStatus(
            SocialAdCampaignRecord campaign,
            long spentCents,
            long remainingBudgetCents,
            long expectedSpentCents,
            Instant now) {
        if (remainingBudgetCents == 0) {
            return "exhausted";
        }
        if (now.isBefore(campaign.startsAt())) {
            return "not_started";
        }
        if (!campaign.endsAt().isAfter(now)) {
            return "ended";
        }
        if (expectedSpentCents == 0) {
            return spentCents > 0 ? "over_pacing" : "on_track";
        }
        double pacingRatio = (double) spentCents / expectedSpentCents;
        if (pacingRatio < 0.8) {
            return "under_pacing";
        }
        if (pacingRatio > 1.2) {
            return "over_pacing";
        }
        return "on_track";
    }
}
