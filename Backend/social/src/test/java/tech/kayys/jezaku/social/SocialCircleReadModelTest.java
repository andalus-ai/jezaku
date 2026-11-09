package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialCircleReadModelTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-05T12:00:00Z");

    @Test
    void pagesGroupAndCommunityDirectoriesWithVisibilityAndQueryFilters() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroup(new SocialGroupRecord("group_alpha", "Camera Alpha", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_beta", "Camera Beta", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_private", "Camera Private", "private", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_skip", "Garden", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_alpha", "Camera City", "invite_only", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_beta", "Camera Field", "invite_only", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_skip", "Camera Public", "public", BASE_TIME));
        SocialCircleReadModel readModel = readModel(repository);

        SocialCircleReadModel.DirectoryPage<SocialGroupRecord> firstGroupPage =
                readModel.groups(1, "", "public", "camera");
        SocialCircleReadModel.DirectoryPage<SocialGroupRecord> secondGroupPage =
                readModel.groups(1, firstGroupPage.nextCursor(), "public", "camera");
        SocialCircleReadModel.DirectoryPage<SocialCommunityRecord> communityPage =
                readModel.communities(10, "", "invite_only", "camera");

        assertEquals(List.of("group_alpha"), groupIds(firstGroupPage));
        assertTrue(firstGroupPage.hasMore());
        assertEquals(List.of("group_beta"), groupIds(secondGroupPage));
        assertFalse(secondGroupPage.hasMore());
        assertEquals(List.of("community_alpha", "community_beta"), communityIds(communityPage));
    }

    @Test
    void pagesTargetAndUserMemberships() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroupMembership(new MembershipRecord("member_b", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_a", "admin", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_c", "group_b", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_b", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_a", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("user_b", "community_c", "member", BASE_TIME));
        SocialCircleReadModel readModel = readModel(repository);

        SocialCircleReadModel.MembershipPage firstMemberPage =
                readModel.targetGroupMembers("group_a", 1, "");
        SocialCircleReadModel.MembershipPage secondMemberPage =
                readModel.targetGroupMembers("group_a", 1, firstMemberPage.nextCursor());
        SocialCircleReadModel.MembershipPage userCommunityPage =
                readModel.userCommunities("user_a", 10, "");

        assertEquals(List.of("member_a"), memberIds(firstMemberPage));
        assertTrue(firstMemberPage.hasMore());
        assertEquals(List.of("member_b"), memberIds(secondMemberPage));
        assertEquals(List.of("community_a", "community_b"), targetIds(userCommunityPage));
    }

    @Test
    void pagesCircleContentAndReportsViewerMembership() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        repository.saveGroupMembership(new MembershipRecord("viewer_a", "group_a", "member", BASE_TIME));
        repository.saveContent(content("content_old", "group", "group_a", BASE_TIME.plusSeconds(10)));
        repository.saveContent(content("content_hidden", "group", "group_a", BASE_TIME.plusSeconds(20)));
        repository.saveContent(content("content_new", "group", "group_a", BASE_TIME.plusSeconds(30)));
        repository.saveContent(content("content_other", "group", "group_b", BASE_TIME.plusSeconds(40)));
        SocialCircleReadModel readModel = readModel(repository);

        SocialCircleReadModel.CircleContentPage firstPage =
                readModel.groupContent("group_a", "viewer_a", 1, "");
        SocialCircleReadModel.CircleContentPage secondPage =
                readModel.groupContent("group_a", "viewer_a", 1, firstPage.nextCursor());

        assertTrue(firstPage.viewerMember());
        assertEquals(List.of("content_new"), contentIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertEquals(List.of("content_old"), contentIds(secondPage));
        assertFalse(secondPage.hasMore());
    }

    private SocialCircleReadModel readModel(InMemorySocialGraphRepository repository) {
        SocialRelationshipPolicy relationshipPolicy = new SocialRelationshipPolicy(repository);
        SocialCircleMembershipPolicy membershipPolicy =
                new SocialCircleMembershipPolicy(repository, relationshipPolicy::blockedEitherWay);
        return new SocialCircleReadModel(
                repository,
                new SocialCircleDirectoryPaginationPlanner(),
                new SocialMembershipPaginationPlanner(),
                new SocialContentPaginationPlanner(),
                membershipPolicy,
                (content, viewerId) -> !"content_hidden".equals(content.contentId()));
    }

    private SocialContentRecord content(
            String contentId,
            String scope,
            String targetId,
            Instant createdAt) {
        return new SocialContentRecord(
                contentId,
                "owner_a",
                "post",
                scope,
                targetId,
                contentId + " caption",
                createdAt);
    }

    private List<String> groupIds(SocialCircleReadModel.DirectoryPage<SocialGroupRecord> page) {
        return page.items().stream().map(SocialGroupRecord::groupId).toList();
    }

    private List<String> communityIds(SocialCircleReadModel.DirectoryPage<SocialCommunityRecord> page) {
        return page.items().stream().map(SocialCommunityRecord::communityId).toList();
    }

    private List<String> memberIds(SocialCircleReadModel.MembershipPage page) {
        return page.memberships().stream().map(MembershipRecord::memberId).toList();
    }

    private List<String> targetIds(SocialCircleReadModel.MembershipPage page) {
        return page.memberships().stream().map(MembershipRecord::targetId).toList();
    }

    private List<String> contentIds(SocialCircleReadModel.CircleContentPage page) {
        return page.contents().stream().map(SocialContentRecord::contentId).toList();
    }
}
