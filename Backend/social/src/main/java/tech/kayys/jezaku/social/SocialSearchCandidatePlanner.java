package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResult;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Set;

final class SocialSearchCandidatePlanner {
    private final SocialGraphRepository repository;
    private final SocialGraphUserIndex userIndex;
    private final SocialEngagementSummaryResolver engagementSummaryResolver;
    private final SocialContentRankingPolicy contentRankingPolicy;
    private final SocialSearchScoringPolicy searchScoringPolicy;
    private final Access access;

    SocialSearchCandidatePlanner(
            SocialGraphRepository repository,
            SocialGraphUserIndex userIndex,
            SocialEngagementSummaryResolver engagementSummaryResolver,
            SocialContentRankingPolicy contentRankingPolicy,
            SocialSearchScoringPolicy searchScoringPolicy,
            Access access) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.userIndex = Objects.requireNonNull(userIndex, "userIndex");
        this.engagementSummaryResolver = Objects.requireNonNull(
                engagementSummaryResolver,
                "engagementSummaryResolver");
        this.contentRankingPolicy = Objects.requireNonNull(contentRankingPolicy, "contentRankingPolicy");
        this.searchScoringPolicy = Objects.requireNonNull(searchScoringPolicy, "searchScoringPolicy");
        this.access = Objects.requireNonNull(access, "access");
    }

    List<SocialSearchResult> candidates(String viewerId, String needle, Set<String> selectedTypes) {
        List<SocialSearchResult> results = new ArrayList<>();
        if (selectedTypes.contains("users")) {
            addUserSearchResults(results, viewerId, needle);
        }
        if (selectedTypes.contains("groups")) {
            addGroupSearchResults(results, viewerId, needle);
        }
        if (selectedTypes.contains("communities")) {
            addCommunitySearchResults(results, viewerId, needle);
        }
        if (selectedTypes.contains("tags")) {
            addTagSearchResults(results, viewerId, needle);
        }
        if (selectedTypes.contains("content")) {
            addContentSearchResults(results, viewerId, needle);
        }
        return results;
    }

    private void addUserSearchResults(List<SocialSearchResult> results, String viewerId, String needle) {
        for (String userId : userIndex.knownUserIds()) {
            SocialUserProfileRecord profile = access.profileFor(userId);
            boolean profileVisible = access.profileVisibleTo(viewerId, userId, profile);
            String privateProfileText = profileVisible
                    ? String.join(" ", profile.bio(), profile.locationLabel())
                    : "";
            if (!searchScoringPolicy.matches(
                    needle,
                    userId,
                    profile.displayName(),
                    profile.handle(),
                    privateProfileText)) {
                continue;
            }
            if (!viewerId.equals(userId) && access.mutedTarget(viewerId, "user", userId)) {
                continue;
            }
            SocialRelationshipContextResponse context = access.relationshipContext(viewerId, userId);
            if (context.blocked() && !viewerId.equals(userId)) {
                continue;
            }
            int visibleContent = access.visibleContentCount(viewerId, userId);
            int followers = access.visibleFollowerCount(userId);
            double score = searchScoringPolicy.userScore(
                    searchScoringPolicy.textMatchScore(
                            needle,
                            profile.displayName(),
                            profile.handle(),
                            userId,
                            privateProfileText),
                    context,
                    followers,
                    visibleContent);
            results.add(new SocialSearchResult(
                    "user",
                    userId,
                    profile.displayName(),
                    "@" + profile.handle(),
                    context.relation(),
                    "",
                    "",
                    0,
                    followers,
                    access.authoredContentCount(userId),
                    visibleContent,
                    score));
        }
    }

    private void addGroupSearchResults(List<SocialSearchResult> results, String viewerId, String needle) {
        for (SocialGroupRecord group : repository.groups()) {
            if (access.mutedTarget(viewerId, "group", group.groupId())) {
                continue;
            }
            boolean viewerMember = memberOf(repository.groupMemberships(), viewerId, group.groupId());
            if (!viewerMember && !"public".equals(group.visibility())) {
                continue;
            }
            if (!searchScoringPolicy.matches(needle, group.groupId(), group.name())) {
                continue;
            }
            int memberCount = (int) repository.groupMemberships().stream()
                    .filter(membership -> membership.targetId().equals(group.groupId()))
                    .filter(membership -> !access.blockedEitherWay(viewerId, membership.memberId()))
                    .count();
            int contentCount = circleContentCount("group", group.groupId());
            int visibleContent = visibleCircleContentCount("group", group.groupId(), viewerId);
            double score = searchScoringPolicy.circleScore(
                    searchScoringPolicy.textMatchScore(needle, group.name(), group.groupId()),
                    viewerMember,
                    memberCount,
                    visibleContent);
            results.add(new SocialSearchResult(
                    "group",
                    group.groupId(),
                    group.name(),
                    group.visibility(),
                    viewerMember ? "member" : "public",
                    group.groupId(),
                    "group",
                    memberCount,
                    0,
                    contentCount,
                    visibleContent,
                    score));
        }
    }

    private void addCommunitySearchResults(List<SocialSearchResult> results, String viewerId, String needle) {
        for (SocialCommunityRecord community : repository.communities()) {
            if (access.mutedTarget(viewerId, "community", community.communityId())) {
                continue;
            }
            boolean viewerMember = memberOf(repository.communityMemberships(), viewerId, community.communityId());
            if (!viewerMember && !"public".equals(community.visibility())) {
                continue;
            }
            if (!searchScoringPolicy.matches(needle, community.communityId(), community.name())) {
                continue;
            }
            int memberCount = (int) repository.communityMemberships().stream()
                    .filter(membership -> membership.targetId().equals(community.communityId()))
                    .filter(membership -> !access.blockedEitherWay(viewerId, membership.memberId()))
                    .count();
            int contentCount = circleContentCount("community", community.communityId());
            int visibleContent = visibleCircleContentCount("community", community.communityId(), viewerId);
            double score = searchScoringPolicy.circleScore(
                    searchScoringPolicy.textMatchScore(needle, community.name(), community.communityId()),
                    viewerMember,
                    memberCount,
                    visibleContent);
            results.add(new SocialSearchResult(
                    "community",
                    community.communityId(),
                    community.name(),
                    community.visibility(),
                    viewerMember ? "member" : "public",
                    community.communityId(),
                    "community",
                    memberCount,
                    0,
                    contentCount,
                    visibleContent,
                    score));
        }
    }

    private void addTagSearchResults(List<SocialSearchResult> results, String viewerId, String needle) {
        repository.tags().stream()
                .map(SocialContentTagRecord::tag)
                .distinct()
                .filter(tag -> searchScoringPolicy.matches(needle, tag, "#" + tag))
                .forEach(tag -> {
                    int contentCount = repository.taggedContent(tag).size();
                    int visibleContent = (int) repository.taggedContent(tag).stream()
                            .map(contentTag -> repository.content(contentTag.contentId()))
                            .filter(content -> content != null)
                            .filter(content -> access.contentAudienceDecision(content, viewerId).canView())
                            .filter(content -> !access.contentHidden(content.contentId(), viewerId))
                            .filter(content -> !access.contentMutedForViewer(content, viewerId))
                            .count();
                    if (visibleContent == 0) {
                        return;
                    }
                    int followers = repository.tagFollows(tag).size();
                    double score = searchScoringPolicy.tagScore(
                            searchScoringPolicy.textMatchScore(needle, tag, "#" + tag),
                            visibleContent,
                            followers);
                    results.add(new SocialSearchResult(
                            "tag",
                            tag,
                            "#" + tag,
                            "topic",
                            repository.tagFollow(viewerId, tag) == null ? "topic" : "followed",
                            "",
                            "",
                            0,
                            followers,
                            contentCount,
                            visibleContent,
                            score));
                });
    }

    private void addContentSearchResults(List<SocialSearchResult> results, String viewerId, String needle) {
        for (SocialContentRecord content : repository.contents()) {
            List<String> tags = access.contentTags(content.contentId());
            String tagText = String.join(" ", tags);
            if (!searchScoringPolicy.matches(
                    needle,
                    content.contentId(),
                    content.caption(),
                    access.userLabel(content.ownerId()),
                    tagText)) {
                continue;
            }
            SocialAudienceDecisionResponse audience = access.contentAudienceDecision(content, viewerId);
            if (!audience.canView()
                    || access.contentHidden(content.contentId(), viewerId)
                    || access.contentMutedForViewer(content, viewerId)) {
                continue;
            }
            SocialEngagementSummaryResolver.ContentEngagementSummary engagement =
                    engagementSummaryResolver.content(content.contentId(), viewerId);
            double score = contentRankingPolicy.contentSearchScore(
                    searchScoringPolicy.textMatchScore(needle, content.caption(), content.contentId(), tagText),
                    content,
                    engagement);
            results.add(new SocialSearchResult(
                    "content",
                    content.contentId(),
                    access.contentTitle(content),
                    access.userLabel(content.ownerId()) + " · " + content.contentType(),
                    audience.reason(),
                    content.targetId(),
                    content.scope(),
                    0,
                    0,
                    1,
                    1,
                    score));
        }
    }

    private int circleContentCount(String scope, String targetId) {
        return (int) repository.contents().stream()
                .filter(content -> content.scope().equals(scope))
                .filter(content -> content.targetId().equals(targetId))
                .count();
    }

    private int visibleCircleContentCount(String scope, String targetId, String viewerId) {
        return (int) repository.contents().stream()
                .filter(content -> content.scope().equals(scope))
                .filter(content -> content.targetId().equals(targetId))
                .filter(content -> access.contentAudienceDecision(content, viewerId).canView())
                .filter(content -> !access.contentHidden(content.contentId(), viewerId))
                .filter(content -> !access.contentMutedForViewer(content, viewerId))
                .count();
    }

    private boolean memberOf(List<MembershipRecord> memberships, String memberId, String targetId) {
        return memberships.stream()
                .anyMatch(membership -> membership.memberId().equals(memberId)
                        && membership.targetId().equals(targetId));
    }

    interface Access {
        SocialUserProfileRecord profileFor(String userId);

        boolean profileVisibleTo(String viewerId, String userId, SocialUserProfileRecord profile);

        SocialRelationshipContextResponse relationshipContext(String viewerId, String userId);

        int visibleContentCount(String viewerId, String ownerId);

        int visibleFollowerCount(String userId);

        int authoredContentCount(String ownerId);

        boolean mutedTarget(String userId, String targetType, String targetId);

        boolean blockedEitherWay(String firstUserId, String secondUserId);

        SocialAudienceDecisionResponse contentAudienceDecision(SocialContentRecord content, String viewerId);

        boolean contentHidden(String contentId, String userId);

        boolean contentMutedForViewer(SocialContentRecord content, String viewerId);

        List<String> contentTags(String contentId);

        String userLabel(String userId);

        String contentTitle(SocialContentRecord content);
    }
}
