package tech.kayys.jezaku.social;

import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;

import java.util.Objects;
import java.util.Set;
import java.util.function.BiFunction;
import java.util.function.BiPredicate;
import java.util.function.Function;

import static tech.kayys.jezaku.validation.TextParams.optionalTrim;

final class AdSocialAccess {
    private final Function<String, SocialGroupRecord> groupResolver;
    private final Function<String, SocialCommunityRecord> communityResolver;
    private final BiPredicate<String, String> groupMember;
    private final BiPredicate<String, String> communityMember;
    private final Function<String, SocialContentRecord> requiredContentResolver;
    private final Function<String, SocialContentRecord> contentReader;
    private final BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> contentAudienceDecision;
    private final BiPredicate<String, String> contentHidden;

    AdSocialAccess(
            Function<String, SocialGroupRecord> groupResolver,
            Function<String, SocialCommunityRecord> communityResolver,
            BiPredicate<String, String> groupMember,
            BiPredicate<String, String> communityMember,
            Function<String, SocialContentRecord> requiredContentResolver,
            Function<String, SocialContentRecord> contentReader,
            BiFunction<SocialContentRecord, String, SocialAudienceDecisionResponse> contentAudienceDecision,
            BiPredicate<String, String> contentHidden) {
        this.groupResolver = Objects.requireNonNull(groupResolver, "groupResolver");
        this.communityResolver = Objects.requireNonNull(communityResolver, "communityResolver");
        this.groupMember = Objects.requireNonNull(groupMember, "groupMember");
        this.communityMember = Objects.requireNonNull(communityMember, "communityMember");
        this.requiredContentResolver = Objects.requireNonNull(requiredContentResolver, "requiredContentResolver");
        this.contentReader = Objects.requireNonNull(contentReader, "contentReader");
        this.contentAudienceDecision = Objects.requireNonNull(contentAudienceDecision, "contentAudienceDecision");
        this.contentHidden = Objects.requireNonNull(contentHidden, "contentHidden");
    }

    void ensureAdvertiserCanTargetGroups(String advertiserId, Set<String> groupIds) {
        if (groupIds == null || groupIds.isEmpty()) {
            return;
        }
        for (String groupId : groupIds) {
            SocialGroupRecord group = groupResolver.apply(groupId);
            if (group == null) {
                throw new NotFoundException("Group not found: " + groupId);
            }
            if (!groupMember.test(advertiserId, group.groupId())) {
                throw new ForbiddenException("Advertiser must be a member of target group: " + group.groupId());
            }
        }
    }

    void ensureAdvertiserCanTargetCommunities(String advertiserId, Set<String> communityIds) {
        if (communityIds == null || communityIds.isEmpty()) {
            return;
        }
        for (String communityId : communityIds) {
            SocialCommunityRecord community = communityResolver.apply(communityId);
            if (community == null) {
                throw new NotFoundException("Community not found: " + communityId);
            }
            if (!communityMember.test(advertiserId, community.communityId())) {
                throw new ForbiddenException(
                        "Advertiser must be a member of target community: " + community.communityId());
            }
        }
    }

    String creativeContentId(String advertiserId, String creativeContentId) {
        String normalizedContentId = optionalTrim(creativeContentId, "");
        if (normalizedContentId.isEmpty()) {
            return "";
        }
        SocialContentRecord content = requiredContentResolver.apply(normalizedContentId);
        if (content == null) {
            throw new NotFoundException("Content not found: " + normalizedContentId);
        }
        if (!content.ownerId().equals(advertiserId)) {
            throw new ForbiddenException("Advertiser must own the creative content");
        }
        return content.contentId();
    }

    boolean creativeVisibleToViewer(SocialAdCampaignRecord campaign, String viewerId) {
        SocialAdCampaignRecord resolvedCampaign = Objects.requireNonNull(campaign, "campaign");
        String creativeContentId = optionalTrim(resolvedCampaign.creativeContentId(), "");
        if (creativeContentId.isEmpty()) {
            return true;
        }
        SocialContentRecord creative = contentReader.apply(creativeContentId);
        if (creative == null || contentHidden.test(creative.contentId(), viewerId)) {
            return false;
        }
        SocialAudienceDecisionResponse decision = contentAudienceDecision.apply(creative, viewerId);
        return decision != null && decision.canView();
    }
}
