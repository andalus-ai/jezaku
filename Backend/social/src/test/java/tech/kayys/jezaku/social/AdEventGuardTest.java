package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.SocialAdAudienceCandidate;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AdEventGuardTest {
    @Test
    void allowsMatchingViewerWhileCampaignIsActiveAndFunded() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");

        assertDoesNotThrow(() -> AdEventGuard.ensureAllowed(
                campaign("approved", "scheduled", now),
                "viewer_a",
                "click",
                now.minusSeconds(5),
                now,
                1_000L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> audienceCandidate()));
    }

    @Test
    void rejectsFutureEventsAndUnmatchedAudience() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");

        assertThrows(BadRequestException.class, () -> AdEventGuard.ensureAllowed(
                campaign("approved", "scheduled", now),
                "viewer_a",
                "impression",
                now.plusSeconds(301),
                now,
                0L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> audienceCandidate()));

        assertThrows(ForbiddenException.class, () -> AdEventGuard.ensureAllowed(
                campaign("approved", "scheduled", now),
                "viewer_a",
                "impression",
                now,
                now,
                0L,
                (advertiserId, viewerId) -> false,
                (campaign, viewerId) -> true,
                (campaign, viewerId) -> null));
    }

    @Test
    void rejectsUnapprovedCreativeAndOverspendAsConflicts() {
        Instant now = Instant.parse("2026-06-02T06:00:00Z");

        WebApplicationException unapproved = assertThrows(WebApplicationException.class, () ->
                AdEventGuard.ensureAllowed(
                        campaign("pending_review", "scheduled", now),
                        "viewer_a",
                        "impression",
                        now,
                        now,
                        0L,
                        (advertiserId, viewerId) -> false,
                        (campaign, viewerId) -> true,
                        (campaign, viewerId) -> audienceCandidate()));
        assertEquals(Response.Status.CONFLICT.getStatusCode(), unapproved.getResponse().getStatus());

        WebApplicationException overspend = assertThrows(WebApplicationException.class, () ->
                AdEventGuard.ensureAllowed(
                        campaign("approved", "scheduled", now),
                        "viewer_a",
                        "click",
                        now,
                        now,
                        9_990L,
                        (advertiserId, viewerId) -> false,
                        (campaign, viewerId) -> true,
                        (campaign, viewerId) -> audienceCandidate()));
        assertEquals(Response.Status.CONFLICT.getStatusCode(), overspend.getResponse().getStatus());
    }

    private SocialAdCampaignRecord campaign(String creativeReviewStatus, String status, Instant now) {
        return new SocialAdCampaignRecord(
                "campaign_a",
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                status,
                "creative_a",
                creativeReviewStatus,
                "",
                "approved".equals(creativeReviewStatus) ? now.minusSeconds(600) : null,
                "USD",
                10_000L,
                now.minusSeconds(3_600),
                now.plusSeconds(3_600),
                2,
                25,
                10,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                now.minusSeconds(7_200),
                now.minusSeconds(1_800));
    }

    private SocialAdAudienceCandidate audienceCandidate() {
        return new SocialAdAudienceCandidate(
                "viewer_a",
                "Viewer A",
                "friend",
                1,
                73.5,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                4,
                82.0,
                List.of("relation:friend"));
    }
}
