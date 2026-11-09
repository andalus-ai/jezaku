package tech.kayys.jezaku.social;

import java.time.Instant;
import java.util.function.BiFunction;
import java.util.function.BiPredicate;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;

final class AdEventGuard {
    private AdEventGuard() {
    }

    static void ensureAllowed(
            SocialAdCampaignRecord campaign,
            String viewerId,
            String eventType,
            Instant occurredAt,
            Instant now,
            long currentSpendCents,
            BiPredicate<String, String> blockedEitherWay,
            BiPredicate<SocialAdCampaignRecord, String> creativeVisibleToViewer,
            BiFunction<SocialAdCampaignRecord, String, SocialAdAudienceCandidate> audienceResolver) {
        if (occurredAt.isAfter(now.plusSeconds(300))) {
            throw new BadRequestException("occurredAt cannot be more than five minutes in the future");
        }
        if (!"scheduled".equals(campaign.status())
                || campaign.startsAt().isAfter(now)
                || !campaign.endsAt().isAfter(now)) {
            throw conflict("Campaign is not active for event tracking");
        }
        if (!AdMonetizationPolicy.creativeApproved(campaign)) {
            throw conflict("Campaign creative is not approved for event tracking");
        }
        if (campaign.advertiserId().equals(viewerId)) {
            throw new BadRequestException("Advertisers cannot record ad events for themselves");
        }
        if (blockedEitherWay.test(campaign.advertiserId(), viewerId)) {
            throw new ForbiddenException("Viewer cannot interact with this advertiser campaign");
        }
        if (!creativeVisibleToViewer.test(campaign, viewerId)) {
            throw new ForbiddenException("Viewer cannot see this campaign creative");
        }
        if (audienceResolver.apply(campaign, viewerId) == null) {
            throw new ForbiddenException("Viewer does not match this campaign audience");
        }
        long projectedSpendCents = currentSpendCents + AdMonetizationPolicy.eventCostCents(eventType);
        if (projectedSpendCents > campaign.budgetCents()) {
            throw conflict("Campaign budget is exhausted");
        }
    }

    private static WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }
}
