package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Supplier;

import jakarta.ws.rs.BadRequestException;
import tech.kayys.jezaku.social.SocialDtos.SocialAdCampaignCreateRequest;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

final class AdCampaignDrafts {
    private static final Set<String> CAMPAIGN_STATUSES = Set.of(
            "draft",
            "scheduled",
            "paused",
            "archived");
    private static final long DEFAULT_CAMPAIGN_SECONDS = 7 * 86_400L;
    private static final long MAX_CAMPAIGN_SECONDS = 90 * 86_400L;
    private static final long MIN_BUDGET_CENTS = 100L;
    private static final long MAX_BUDGET_CENTS = 100_000_000_000L;

    private AdCampaignDrafts() {
    }

    record DraftTerms(
            String campaignId,
            String advertiserId,
            String name,
            String objective,
            String creativeContentId,
            String creativeReviewStatus,
            String budgetCurrency,
            long budgetCents,
            Instant startsAt,
            Instant endsAt,
            int maxDepth,
            int audienceLimit,
            Instant createdAt) {
    }

    static String campaignId(String requestedCampaignId, Supplier<String> fallbackId) {
        String campaignId = optionalTrim(requestedCampaignId, "");
        return campaignId.isEmpty() ? fallbackId.get() : campaignId;
    }

    static DraftTerms terms(
            String campaignId,
            SocialAdCampaignCreateRequest request,
            String advertiserId,
            String objective,
            String creativeContentId,
            int maxDepth,
            int audienceLimit,
            Instant now) {
        Instant startsAt = request.startsAt() == null ? now : request.startsAt();
        Instant endsAt = request.endsAt() == null ? startsAt.plusSeconds(DEFAULT_CAMPAIGN_SECONDS) : request.endsAt();
        ensureSchedule(startsAt, endsAt);
        return new DraftTerms(
                campaignId,
                advertiserId,
                requireTextMaxLength(request.name(), "name", 120),
                objective,
                creativeContentId,
                AdMonetizationPolicy.initialCreativeReviewStatus(creativeContentId),
                budgetCurrency(request.budgetCurrency()),
                budgetCents(request.budgetCents()),
                startsAt,
                endsAt,
                maxDepth,
                audienceLimit,
                now);
    }

    static SocialAdCampaignRecord record(
            DraftTerms terms,
            int estimatedReach,
            Set<String> relationScopes,
            Set<String> targetTags,
            Set<String> targetGroupIds,
            Set<String> targetCommunityIds) {
        return new SocialAdCampaignRecord(
                terms.campaignId(),
                terms.advertiserId(),
                terms.name(),
                terms.objective(),
                "draft",
                terms.creativeContentId(),
                terms.creativeReviewStatus(),
                "",
                null,
                terms.budgetCurrency(),
                terms.budgetCents(),
                terms.startsAt(),
                terms.endsAt(),
                terms.maxDepth(),
                terms.audienceLimit(),
                estimatedReach,
                sorted(relationScopes),
                sorted(targetTags),
                sorted(targetGroupIds),
                sorted(targetCommunityIds),
                terms.createdAt(),
                terms.createdAt());
    }

    static String status(String status) {
        return optionalChoice(status, "draft", CAMPAIGN_STATUSES,
                "status", "status must be draft, scheduled, paused, or archived");
    }

    static String statusFilter(String status) {
        Set<String> statuses = new HashSet<>(CAMPAIGN_STATUSES);
        statuses.add("all");
        return optionalChoice(status, "all", statuses,
                "status", "status must be draft, scheduled, paused, archived, or all");
    }

    private static String budgetCurrency(String currency) {
        String normalized = optionalTrim(currency, "USD").toUpperCase(java.util.Locale.ROOT);
        if (!normalized.matches("[A-Z]{3}")) {
            throw new BadRequestException("budgetCurrency must be a three-letter currency code");
        }
        return normalized;
    }

    private static long budgetCents(Long budgetCents) {
        if (budgetCents == null) {
            throw new BadRequestException("budgetCents is required");
        }
        if (budgetCents < MIN_BUDGET_CENTS) {
            throw new BadRequestException("budgetCents must be at least 100");
        }
        if (budgetCents > MAX_BUDGET_CENTS) {
            throw new BadRequestException("budgetCents is too large for a draft campaign");
        }
        return budgetCents;
    }

    private static void ensureSchedule(Instant startsAt, Instant endsAt) {
        if (!endsAt.isAfter(startsAt)) {
            throw new BadRequestException("endsAt must be after startsAt");
        }
        if (endsAt.isAfter(startsAt.plusSeconds(MAX_CAMPAIGN_SECONDS))) {
            throw new BadRequestException("Campaign drafts may run at most 90 days");
        }
    }

    private static List<String> sorted(Set<String> values) {
        return values.stream().sorted().toList();
    }
}
