package tech.kayys.jezaku.social;

import java.util.List;
import java.util.Locale;
import java.util.function.BiPredicate;

final class SocialCircleReadModel {
    private final SocialGraphRepository repository;
    private final SocialCircleDirectoryPaginationPlanner directoryPaginationPlanner;
    private final SocialMembershipPaginationPlanner membershipPaginationPlanner;
    private final SocialContentPaginationPlanner contentPaginationPlanner;
    private final SocialCircleMembershipPolicy membershipPolicy;
    private final BiPredicate<SocialContentRecord, String> contentVisibleToViewer;

    SocialCircleReadModel(
            SocialGraphRepository repository,
            SocialCircleDirectoryPaginationPlanner directoryPaginationPlanner,
            SocialMembershipPaginationPlanner membershipPaginationPlanner,
            SocialContentPaginationPlanner contentPaginationPlanner,
            SocialCircleMembershipPolicy membershipPolicy,
            BiPredicate<SocialContentRecord, String> contentVisibleToViewer) {
        this.repository = repository;
        this.directoryPaginationPlanner = directoryPaginationPlanner;
        this.membershipPaginationPlanner = membershipPaginationPlanner;
        this.contentPaginationPlanner = contentPaginationPlanner;
        this.membershipPolicy = membershipPolicy;
        this.contentVisibleToViewer = contentVisibleToViewer;
    }

    DirectoryPage<SocialGroupRecord> groups(int limit, String cursor, String visibility, String needle) {
        List<SocialGroupRecord> candidates = repository.groups().stream()
                .filter(group -> directoryMatches(group.groupId(), group.name(), group.visibility(), visibility, needle))
                .toList();
        SocialCircleDirectoryPaginationPlanner.Page<SocialGroupRecord> page =
                directoryPaginationPlanner.groups(limit, cursor, candidates);
        return new DirectoryPage<>(page.items(), page.hasMore(), page.nextCursor());
    }

    DirectoryPage<SocialCommunityRecord> communities(int limit, String cursor, String visibility, String needle) {
        List<SocialCommunityRecord> candidates = repository.communities().stream()
                .filter(community -> directoryMatches(
                        community.communityId(),
                        community.name(),
                        community.visibility(),
                        visibility,
                        needle))
                .toList();
        SocialCircleDirectoryPaginationPlanner.Page<SocialCommunityRecord> page =
                directoryPaginationPlanner.communities(limit, cursor, candidates);
        return new DirectoryPage<>(page.items(), page.hasMore(), page.nextCursor());
    }

    MembershipPage targetGroupMembers(String groupId, int limit, String cursor) {
        return targetMembers(groupId, repository.groupMemberships(), limit, cursor);
    }

    MembershipPage userGroups(String userId, int limit, String cursor) {
        return userMemberships(userId, repository.groupMemberships(), limit, cursor);
    }

    MembershipPage targetCommunityMembers(String communityId, int limit, String cursor) {
        return targetMembers(communityId, repository.communityMemberships(), limit, cursor);
    }

    MembershipPage userCommunities(String userId, int limit, String cursor) {
        return userMemberships(userId, repository.communityMemberships(), limit, cursor);
    }

    CircleContentPage groupContent(String groupId, String viewerId, int limit, String cursor) {
        return circleContent("group", groupId, repository.groupMemberships(), viewerId, limit, cursor);
    }

    CircleContentPage communityContent(String communityId, String viewerId, int limit, String cursor) {
        return circleContent("community", communityId, repository.communityMemberships(), viewerId, limit, cursor);
    }

    private MembershipPage targetMembers(
            String targetId,
            List<MembershipRecord> memberships,
            int limit,
            String cursor) {
        SocialMembershipPaginationPlanner.Page page =
                membershipPaginationPlanner.targetMembers(limit, cursor, targetId, memberships);
        return new MembershipPage(page.memberships(), page.hasMore(), page.nextCursor());
    }

    private MembershipPage userMemberships(
            String userId,
            List<MembershipRecord> memberships,
            int limit,
            String cursor) {
        SocialMembershipPaginationPlanner.Page page =
                membershipPaginationPlanner.userMemberships(limit, cursor, userId, memberships);
        return new MembershipPage(page.memberships(), page.hasMore(), page.nextCursor());
    }

    private CircleContentPage circleContent(
            String scope,
            String targetId,
            List<MembershipRecord> memberships,
            String viewerId,
            int limit,
            String cursor) {
        List<SocialContentPaginationPlanner.ContentCandidate> candidates = repository.contents().stream()
                .filter(content -> content.scope().equals(scope))
                .filter(content -> content.targetId().equals(targetId))
                .filter(content -> contentVisibleToViewer.test(content, viewerId))
                .map(content -> new SocialContentPaginationPlanner.ContentCandidate(content, content.createdAt()))
                .toList();
        SocialContentPaginationPlanner.Page page = contentPaginationPlanner.timeline(limit, cursor, candidates);
        return new CircleContentPage(
                page.contents(),
                membershipPolicy.memberOf(memberships, viewerId, targetId),
                page.hasMore(),
                page.nextCursor());
    }

    private boolean directoryMatches(
            String id,
            String name,
            String visibility,
            String visibilityFilter,
            String needle) {
        if (!"all".equals(visibilityFilter) && !visibilityFilter.equals(visibility)) {
            return false;
        }
        return needle.isBlank()
                || id.toLowerCase(Locale.ROOT).contains(needle)
                || name.toLowerCase(Locale.ROOT).contains(needle);
    }

    record DirectoryPage<T>(List<T> items, boolean hasMore, String nextCursor) {
    }

    record MembershipPage(List<MembershipRecord> memberships, boolean hasMore, String nextCursor) {
    }

    record CircleContentPage(
            List<SocialContentRecord> contents,
            boolean viewerMember,
            boolean hasMore,
            String nextCursor) {
    }
}
