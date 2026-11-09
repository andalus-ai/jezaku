package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AdSocialAccessTest {
    @Test
    void validatesCircleTargetsAgainstAdvertiserMembership() {
        AdSocialAccess access = access(Map.of(), Set.of());

        assertDoesNotThrow(() -> access.ensureAdvertiserCanTargetGroups("advertiser_a", Set.of("group_a")));
        assertDoesNotThrow(() -> access.ensureAdvertiserCanTargetCommunities("advertiser_a", Set.of("community_a")));
        assertThrows(ForbiddenException.class,
                () -> access.ensureAdvertiserCanTargetGroups("advertiser_a", Set.of("group_b")));
        assertThrows(ForbiddenException.class,
                () -> access.ensureAdvertiserCanTargetCommunities("advertiser_a", Set.of("community_b")));
        assertThrows(NotFoundException.class,
                () -> access.ensureAdvertiserCanTargetGroups("advertiser_a", Set.of("missing")));
        assertThrows(NotFoundException.class,
                () -> access.ensureAdvertiserCanTargetCommunities("advertiser_a", Set.of("missing")));
    }

    @Test
    void normalizesCreativeContentAndEnforcesOwnership() {
        Instant now = Instant.parse("2026-06-02T14:00:00Z");
        SocialContentRecord ownedCreative = content("creative_a", "advertiser_a", now);
        SocialContentRecord otherCreative = content("creative_b", "someone_else", now);
        AdSocialAccess access = access(
                Map.of(ownedCreative.contentId(), ownedCreative, otherCreative.contentId(), otherCreative),
                Set.of());

        assertEquals("", access.creativeContentId("advertiser_a", "  "));
        assertEquals("creative_a", access.creativeContentId("advertiser_a", " creative_a "));
        assertThrows(ForbiddenException.class, () -> access.creativeContentId("advertiser_a", "creative_b"));
        assertThrows(NotFoundException.class, () -> access.creativeContentId("advertiser_a", "missing"));
    }

    @Test
    void checksCreativeVisibilityAgainstContentAudienceAndHiddenState() {
        Instant now = Instant.parse("2026-06-02T14:00:00Z");
        SocialContentRecord creative = content("creative_a", "advertiser_a", now);
        HashSet<String> hiddenUsers = new HashSet<>();
        AdSocialAccess access = access(Map.of(creative.contentId(), creative), hiddenUsers);

        assertTrue(access.creativeVisibleToViewer(campaign("", now), "viewer_a"));
        assertTrue(access.creativeVisibleToViewer(campaign("creative_a", now), "viewer_a"));
        assertFalse(access.creativeVisibleToViewer(campaign("creative_a", now), "viewer_blocked"));
        assertFalse(access.creativeVisibleToViewer(campaign("missing", now), "viewer_a"));

        hiddenUsers.add("viewer_a");
        assertFalse(access.creativeVisibleToViewer(campaign("creative_a", now), "viewer_a"));
    }

    private AdSocialAccess access(Map<String, SocialContentRecord> contents, Set<String> hiddenUsers) {
        return new AdSocialAccess(
                groupId -> "missing".equals(groupId)
                        ? null
                        : new SocialGroupRecord(groupId, groupId, "public", Instant.EPOCH),
                communityId -> "missing".equals(communityId)
                        ? null
                        : new SocialCommunityRecord(communityId, communityId, "public", Instant.EPOCH),
                (advertiserId, groupId) -> "advertiser_a".equals(advertiserId) && "group_a".equals(groupId),
                (advertiserId, communityId) -> "advertiser_a".equals(advertiserId)
                        && "community_a".equals(communityId),
                contents::get,
                contents::get,
                (content, viewerId) -> audienceDecision(content, viewerId, "viewer_a".equals(viewerId)),
                (contentId, viewerId) -> hiddenUsers.contains(viewerId));
    }

    private SocialAudienceDecisionResponse audienceDecision(
            SocialContentRecord content,
            String viewerId,
            boolean canView) {
        return new SocialAudienceDecisionResponse(
                content.ownerId(),
                viewerId,
                content.scope(),
                content.targetId(),
                canView,
                canView ? "visible" : "blocked",
                "none",
                false,
                content.ownerId().equals(viewerId),
                false,
                false,
                null);
    }

    private SocialContentRecord content(String contentId, String ownerId, Instant now) {
        return new SocialContentRecord(
                contentId,
                ownerId,
                "photo",
                "public",
                "",
                "Creative",
                now);
    }

    private SocialAdCampaignRecord campaign(String creativeContentId, Instant now) {
        return new SocialAdCampaignRecord(
                "campaign_a",
                "advertiser_a",
                "Neighborhood launch",
                "engagement",
                "scheduled",
                creativeContentId,
                "approved",
                "",
                now.minusSeconds(600),
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
}
