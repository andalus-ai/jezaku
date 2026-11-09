package tech.kayys.jezaku.social;

import org.eclipse.microprofile.config.Config;
import org.eclipse.microprofile.config.ConfigValue;
import org.eclipse.microprofile.config.spi.ConfigSource;
import org.eclipse.microprofile.config.spi.Converter;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.BlockListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleContentModerationListResponse;
import tech.kayys.jezaku.social.SocialDtos.CircleMembershipRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendListResponse;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestListResponse;
import tech.kayys.jezaku.social.SocialDtos.MembershipListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommunityListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialReactionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialRecommendationsResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialSearchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowListResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequestListResponse;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SocialRelationshipCursorPaginationTest {
    private static final Instant BASE_TIME = Instant.parse("2026-06-02T12:00:00Z");

    @Test
    void paginatesFriendsCloseFriendsFollowersAndFollowingWithStableCursor() {
        InMemorySocialGraphRepository repository = repository(
                "owner_a",
                "friend_new",
                "friend_old",
                "follower_new",
                "follower_old",
                "followed_new",
                "followed_old");
        SocialService service = service(repository);
        repository.saveFriendship("owner_a", "friend_new", BASE_TIME.plusSeconds(40));
        repository.saveFriendship("owner_a", "friend_old", BASE_TIME.plusSeconds(30));
        repository.saveCloseFriend("owner_a", "friend_new", BASE_TIME.plusSeconds(40));
        repository.saveCloseFriend("owner_a", "friend_old", BASE_TIME.plusSeconds(30));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "follower_new",
                "owner_a",
                BASE_TIME.plusSeconds(40)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "follower_old",
                "owner_a",
                BASE_TIME.plusSeconds(30)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "owner_a",
                "followed_new",
                BASE_TIME.plusSeconds(40)));
        repository.saveUserFollow(new SocialUserFollowRecord(
                "owner_a",
                "followed_old",
                BASE_TIME.plusSeconds(30)));

        FriendListResponse firstFriendPage = service.friends("owner_a", "owner_a", 1, "")
                .await().indefinitely();
        FriendListResponse secondFriendPage = service.friends("owner_a", "owner_a", 1, firstFriendPage.nextCursor())
                .await().indefinitely();
        FriendListResponse firstCloseFriendPage = service.closeFriends("owner_a", "owner_a", 1, "")
                .await().indefinitely();
        FriendListResponse secondCloseFriendPage = service.closeFriends(
                        "owner_a",
                        "owner_a",
                        1,
                        firstCloseFriendPage.nextCursor())
                .await().indefinitely();
        SocialUserFollowListResponse firstFollowerPage = service.followers("owner_a", "owner_a", 1, "")
                .await().indefinitely();
        SocialUserFollowListResponse secondFollowerPage = service.followers(
                        "owner_a",
                        "owner_a",
                        1,
                        firstFollowerPage.nextCursor())
                .await().indefinitely();
        SocialUserFollowListResponse firstFollowingPage = service.following("owner_a", "owner_a", 1, "")
                .await().indefinitely();
        SocialUserFollowListResponse secondFollowingPage = service.following(
                        "owner_a",
                        "owner_a",
                        1,
                        firstFollowingPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("friend_new"), friendIds(firstFriendPage));
        assertTrue(firstFriendPage.hasMore());
        assertFalse(firstFriendPage.nextCursor().isBlank());
        assertEquals(List.of("friend_old"), friendIds(secondFriendPage));
        assertFalse(secondFriendPage.hasMore());
        assertEquals("", secondFriendPage.nextCursor());
        assertEquals(List.of("friend_new"), friendIds(firstCloseFriendPage));
        assertTrue(firstCloseFriendPage.hasMore());
        assertEquals(List.of("friend_old"), friendIds(secondCloseFriendPage));
        assertFalse(secondCloseFriendPage.hasMore());
        assertEquals(List.of("follower_new"), followerIds(firstFollowerPage));
        assertTrue(firstFollowerPage.hasMore());
        assertEquals(List.of("follower_old"), followerIds(secondFollowerPage));
        assertFalse(secondFollowerPage.hasMore());
        assertEquals(List.of("followed_new"), followedIds(firstFollowingPage));
        assertTrue(firstFollowingPage.hasMore());
        assertEquals(List.of("followed_old"), followedIds(secondFollowingPage));
        assertFalse(secondFollowingPage.hasMore());
    }

    @Test
    void paginatesUserFollowRequestsWithStableCursor() {
        InMemorySocialGraphRepository repository = repository("owner_a", "request_new", "request_old");
        SocialService service = service(repository);
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "request_new",
                "owner_a",
                "pending",
                BASE_TIME.plusSeconds(10),
                BASE_TIME.plusSeconds(40)));
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "request_old",
                "owner_a",
                "pending",
                BASE_TIME.plusSeconds(10),
                BASE_TIME.plusSeconds(30)));

        SocialUserFollowRequestListResponse firstPage = service.userFollowRequests(
                        "owner_a",
                        "incoming",
                        "pending",
                        1,
                        "")
                .await().indefinitely();
        SocialUserFollowRequestListResponse secondPage = service.userFollowRequests(
                        "owner_a",
                        "incoming",
                        "pending",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("request_new"), requestFollowerIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("request_old"), requestFollowerIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesFriendRequestsWithStatusFilterAndStableCursor() {
        InMemorySocialGraphRepository repository = repository(
                "owner_a",
                "request_new",
                "request_old",
                "request_accepted");
        SocialService service = service(repository);
        repository.saveFriendRequest(new FriendRequestRecord(
                "friend_request_new",
                "request_new",
                "owner_a",
                "new",
                "pending",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveFriendRequest(new FriendRequestRecord(
                "friend_request_old",
                "request_old",
                "owner_a",
                "old",
                "pending",
                BASE_TIME.plusSeconds(30),
                BASE_TIME.plusSeconds(30)));
        repository.saveFriendRequest(new FriendRequestRecord(
                "friend_request_accepted",
                "request_accepted",
                "owner_a",
                "accepted",
                "accepted",
                BASE_TIME.plusSeconds(50),
                BASE_TIME.plusSeconds(50)));

        FriendRequestListResponse firstPage = service.friendRequests("owner_a", "incoming", "pending", 1, "")
                .await().indefinitely();
        FriendRequestListResponse secondPage = service.friendRequests(
                        "owner_a",
                        "incoming",
                        "pending",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("friend_request_new"), friendRequestIds(firstPage));
        assertEquals("pending", firstPage.status());
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("friend_request_old"), friendRequestIds(secondPage));
        assertFalse(secondPage.hasMore());
        assertEquals("", secondPage.nextCursor());
    }

    @Test
    void paginatesBlocksMutesAndFamilyLinksWithStableCursor() {
        InMemorySocialGraphRepository repository = repository(
                "owner_a",
                "blocked_new",
                "blocked_old",
                "family_new",
                "family_old");
        SocialService service = service(repository);
        repository.saveBlock(new BlockRecord("owner_a", "blocked_new", "new", BASE_TIME.plusSeconds(40)));
        repository.saveBlock(new BlockRecord("owner_a", "blocked_old", "old", BASE_TIME.plusSeconds(30)));
        repository.saveMute(new SocialMuteRecord("owner_a", "user", "muted_new", "new", BASE_TIME.plusSeconds(40)));
        repository.saveMute(new SocialMuteRecord("owner_a", "user", "muted_old", "old", BASE_TIME.plusSeconds(30)));
        repository.saveFamilyLink(new FamilyLinkRecord("owner_a", "family_new", "sibling", BASE_TIME.plusSeconds(40)));
        repository.saveFamilyLink(new FamilyLinkRecord("owner_a", "family_old", "guardian", BASE_TIME.plusSeconds(30)));

        BlockListResponse firstBlockPage = service.blocks("owner_a", 1, "")
                .await().indefinitely();
        BlockListResponse secondBlockPage = service.blocks("owner_a", 1, firstBlockPage.nextCursor())
                .await().indefinitely();
        SocialMuteListResponse firstMutePage = service.mutes("owner_a", "user", 1, "")
                .await().indefinitely();
        SocialMuteListResponse secondMutePage = service.mutes("owner_a", "user", 1, firstMutePage.nextCursor())
                .await().indefinitely();
        FamilyLinkListResponse firstFamilyPage = service.family("owner_a", 1, "")
                .await().indefinitely();
        FamilyLinkListResponse secondFamilyPage = service.family("owner_a", 1, firstFamilyPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("blocked_new"), blockedUserIds(firstBlockPage));
        assertTrue(firstBlockPage.hasMore());
        assertFalse(firstBlockPage.nextCursor().isBlank());
        assertEquals(List.of("blocked_old"), blockedUserIds(secondBlockPage));
        assertFalse(secondBlockPage.hasMore());
        assertEquals("", secondBlockPage.nextCursor());
        assertEquals(List.of("muted_new"), muteTargetIds(firstMutePage));
        assertTrue(firstMutePage.hasMore());
        assertEquals(List.of("muted_old"), muteTargetIds(secondMutePage));
        assertFalse(secondMutePage.hasMore());
        assertEquals(List.of("family_new"), familySecondUserIds(firstFamilyPage));
        assertTrue(firstFamilyPage.hasMore());
        assertEquals(List.of("family_old"), familySecondUserIds(secondFamilyPage));
        assertFalse(secondFamilyPage.hasMore());
    }

    @Test
    void paginatesRecommendationsWithStableScoreCursor() {
        InMemorySocialGraphRepository repository = repository(
                "user_a",
                "bridge",
                "mutual_shared_candidate",
                "family_candidate",
                "mutual_candidate");
        SocialService service = service(repository);
        repository.saveFriendship("user_a", "bridge", BASE_TIME);
        repository.saveFriendship("bridge", "mutual_shared_candidate", BASE_TIME);
        repository.saveFriendship("bridge", "mutual_candidate", BASE_TIME);
        repository.saveFamilyLink(new FamilyLinkRecord("user_a", "family_candidate", "sibling", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_a", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("mutual_shared_candidate", "group_a", "member", BASE_TIME));

        SocialRecommendationsResponse firstPage = service.recommendations("user_a", 1, "")
                .await().indefinitely();
        SocialRecommendationsResponse secondPage = service.recommendations("user_a", 1, firstPage.nextCursor())
                .await().indefinitely();
        SocialRecommendationsResponse thirdPage = service.recommendations("user_a", 1, secondPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("mutual_shared_candidate"), recommendationUserIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("family_candidate"), recommendationUserIds(secondPage));
        assertTrue(secondPage.hasMore());
        assertFalse(secondPage.nextCursor().isBlank());
        assertEquals(List.of("mutual_candidate"), recommendationUserIds(thirdPage));
        assertFalse(thirdPage.hasMore());
        assertEquals("", thirdPage.nextCursor());
    }

    @Test
    void paginatesSearchResultsWithStableRankCursor() {
        InMemorySocialGraphRepository repository = repository(
                "viewer_search",
                "searchpage_alpha",
                "searchpage_beta",
                "searchpage_gamma");
        SocialService service = service(repository);

        SocialSearchResponse firstPage = service.search("viewer_search", "searchpage", "users", 1, "")
                .await().indefinitely();
        SocialSearchResponse secondPage = service.search(
                        "viewer_search",
                        "searchpage",
                        "users",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();
        SocialSearchResponse thirdPage = service.search(
                        "viewer_search",
                        "searchpage",
                        "users",
                        1,
                        secondPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("searchpage_alpha"), searchResultIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("searchpage_beta"), searchResultIds(secondPage));
        assertTrue(secondPage.hasMore());
        assertFalse(secondPage.nextCursor().isBlank());
        assertEquals(List.of("searchpage_gamma"), searchResultIds(thirdPage));
        assertFalse(thirdPage.hasMore());
        assertEquals("", thirdPage.nextCursor());
    }

    @Test
    void deletesThreadedCommentCascadeWithoutLeavingRepliesOrReactions() {
        InMemorySocialGraphRepository repository = repository("user_current", "user_lens", "user_rooftop");
        saveGroupWithOwner(repository, "group_rooftop_creators", "user_current");
        repository.saveGroupMembership(new MembershipRecord("user_lens", "group_rooftop_creators", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("user_rooftop", "group_rooftop_creators", "member", BASE_TIME));
        SocialService service = service(repository);
        service.createContent(new SocialContentCreateRequest(
                        "threaded_comment_content",
                        "user_current",
                        "photo",
                        "group",
                        "group_rooftop_creators",
                        "Thread source"))
                .await().indefinitely();
        String parentCommentId = service.addComment(
                        "threaded_comment_content",
                        new SocialCommentCreateRequest("user_lens", "Top-level thought", ""))
                .await().indefinitely()
                .commentId();
        String replyCommentId = service.addComment(
                        "threaded_comment_content",
                        new SocialCommentCreateRequest("user_rooftop", "Replying into the thread", parentCommentId))
                .await().indefinitely()
                .commentId();
        service.likeComment(
                        "threaded_comment_content",
                        replyCommentId,
                        new SocialReactionRequest("user_lens", "like"))
                .await().indefinitely();

        service.removeComment("threaded_comment_content", parentCommentId, "user_current")
                .await().indefinitely();

        assertNull(repository.comment(parentCommentId));
        assertNull(repository.comment(replyCommentId));
        assertTrue(repository.commentReactions(replyCommentId).isEmpty());
    }

    @Test
    void paginatesCircleMembershipListsWithStableCursor() {
        InMemorySocialGraphRepository repository = repository(
                "owner_a",
                "admin_a",
                "member_a",
                "circle_user");
        SocialService service = service(repository);
        repository.saveGroup(new SocialGroupRecord("group_page", "Group Page", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_alpha", "Group Alpha", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_beta", "Group Beta", "public", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_page", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("admin_a", "group_page", "admin", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("member_a", "group_page", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("circle_user", "group_alpha", "member", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("circle_user", "group_beta", "member", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_page", "Community Page", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_alpha", "Community Alpha", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_beta", "Community Beta", "public", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("owner_a", "community_page", "owner", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("admin_a", "community_page", "admin", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("member_a", "community_page", "member", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord(
                "circle_user",
                "community_alpha",
                "member",
                BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord(
                "circle_user",
                "community_beta",
                "member",
                BASE_TIME));

        MembershipListResponse firstGroupMemberPage = service.groupMembers("group_page", 1, "")
                .await().indefinitely();
        MembershipListResponse secondGroupMemberPage = service.groupMembers(
                        "group_page",
                        1,
                        firstGroupMemberPage.nextCursor())
                .await().indefinitely();
        MembershipListResponse firstUserGroupPage = service.userGroups("circle_user", 1, "")
                .await().indefinitely();
        MembershipListResponse secondUserGroupPage = service.userGroups(
                        "circle_user",
                        1,
                        firstUserGroupPage.nextCursor())
                .await().indefinitely();
        MembershipListResponse firstCommunityMemberPage = service.communityMembers("community_page", 1, "")
                .await().indefinitely();
        MembershipListResponse secondCommunityMemberPage = service.communityMembers(
                        "community_page",
                        1,
                        firstCommunityMemberPage.nextCursor())
                .await().indefinitely();
        MembershipListResponse firstUserCommunityPage = service.userCommunities("circle_user", 1, "")
                .await().indefinitely();
        MembershipListResponse secondUserCommunityPage = service.userCommunities(
                        "circle_user",
                        1,
                        firstUserCommunityPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("admin_a"), membershipMemberIds(firstGroupMemberPage));
        assertTrue(firstGroupMemberPage.hasMore());
        assertFalse(firstGroupMemberPage.nextCursor().isBlank());
        assertEquals(List.of("member_a"), membershipMemberIds(secondGroupMemberPage));
        assertTrue(secondGroupMemberPage.hasMore());
        assertEquals(List.of("group_alpha"), membershipTargetIds(firstUserGroupPage));
        assertTrue(firstUserGroupPage.hasMore());
        assertEquals(List.of("group_beta"), membershipTargetIds(secondUserGroupPage));
        assertFalse(secondUserGroupPage.hasMore());
        assertEquals(List.of("admin_a"), membershipMemberIds(firstCommunityMemberPage));
        assertTrue(firstCommunityMemberPage.hasMore());
        assertEquals(List.of("member_a"), membershipMemberIds(secondCommunityMemberPage));
        assertTrue(secondCommunityMemberPage.hasMore());
        assertEquals(List.of("community_alpha"), membershipTargetIds(firstUserCommunityPage));
        assertTrue(firstUserCommunityPage.hasMore());
        assertEquals(List.of("community_beta"), membershipTargetIds(secondUserCommunityPage));
        assertFalse(secondUserCommunityPage.hasMore());
        assertEquals("", secondUserCommunityPage.nextCursor());
    }

    @Test
    void paginatesCircleDirectoriesWithStableNameCursor() {
        InMemorySocialGraphRepository repository = repository("owner_a", "viewer_a", "inviter_a");
        SocialService service = service(repository);
        repository.saveGroup(new SocialGroupRecord("group_beta", "Beta Group", "private", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_alpha", "Alpha Artists", "public", BASE_TIME));
        repository.saveGroup(new SocialGroupRecord("group_gamma", "Gamma Artists", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_beta", "Beta Community", "private", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_alpha", "Alpha Camera", "public", BASE_TIME));
        repository.saveCommunity(new SocialCommunityRecord("community_gamma", "Gamma Camera", "invite_only", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_alpha", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("viewer_a", "group_alpha", "member", BASE_TIME.plusSeconds(1)));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_beta", "owner", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord("owner_a", "group_gamma", "owner", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("owner_a", "community_alpha", "owner", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("owner_a", "community_beta", "owner", BASE_TIME));
        repository.saveCommunityMembership(new MembershipRecord("inviter_a", "community_gamma", "owner", BASE_TIME));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "directory_join_request",
                "group_beta",
                "group",
                "viewer_a",
                "viewer_a",
                "join_request",
                "pending",
                "Please add me",
                BASE_TIME.plusSeconds(3),
                BASE_TIME.plusSeconds(3)));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "directory_invite",
                "community_gamma",
                "community",
                "viewer_a",
                "inviter_a",
                "invite",
                "pending",
                "Join us",
                BASE_TIME.plusSeconds(4),
                BASE_TIME.plusSeconds(4)));

        SocialGroupListResponse firstGroupPage = service.groups(1, "")
                .await().indefinitely();
        SocialGroupListResponse secondGroupPage = service.groups(1, firstGroupPage.nextCursor())
                .await().indefinitely();
        SocialCommunityListResponse firstCommunityPage = service.communities(1, "")
                .await().indefinitely();
        SocialCommunityListResponse secondCommunityPage = service.communities(1, firstCommunityPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("group_alpha"), groupIds(firstGroupPage));
        assertTrue(firstGroupPage.hasMore());
        assertFalse(firstGroupPage.nextCursor().isBlank());
        assertEquals(List.of("group_beta"), groupIds(secondGroupPage));
        assertTrue(secondGroupPage.hasMore());
        assertEquals(List.of("community_alpha"), communityIds(firstCommunityPage));
        assertTrue(firstCommunityPage.hasMore());
        assertFalse(firstCommunityPage.nextCursor().isBlank());
        assertEquals(List.of("community_beta"), communityIds(secondCommunityPage));
        assertTrue(secondCommunityPage.hasMore());

        SocialGroupListResponse filteredGroupPage = service.groups(5, "", "artists", "public", "viewer_a")
                .await().indefinitely();
        SocialGroupListResponse privateGroupPage = service.groups(5, "", "group", "private", "viewer_a")
                .await().indefinitely();
        SocialCommunityListResponse filteredCommunityPage = service.communities(5, "", "camera", "invite_only", "viewer_a")
                .await().indefinitely();

        assertEquals(List.of("group_alpha", "group_gamma"), groupIds(filteredGroupPage));
        assertFalse(filteredGroupPage.hasMore());
        assertEquals("", filteredGroupPage.nextCursor());
        var alphaGroup = filteredGroupPage.groups().get(0);
        var gammaGroup = filteredGroupPage.groups().get(1);
        assertEquals("member", alphaGroup.viewerRole());
        assertTrue(alphaGroup.viewerMember());
        assertFalse(alphaGroup.canJoin());
        assertTrue(alphaGroup.canLeave());
        assertFalse(gammaGroup.viewerMember());
        assertTrue(gammaGroup.canJoin());
        assertFalse(gammaGroup.canRequestJoin());
        assertEquals(List.of("group_beta"), groupIds(privateGroupPage));
        assertTrue(privateGroupPage.groups().get(0).viewerPendingJoinRequest());
        assertFalse(privateGroupPage.groups().get(0).canRequestJoin());
        assertEquals(List.of("community_gamma"), communityIds(filteredCommunityPage));
        assertFalse(filteredCommunityPage.hasMore());
        assertEquals("", filteredCommunityPage.nextCursor());
        assertTrue(filteredCommunityPage.communities().get(0).viewerPendingInvite());
        assertFalse(filteredCommunityPage.communities().get(0).canJoin());
        assertFalse(filteredCommunityPage.communities().get(0).canRequestJoin());
    }

    @Test
    void paginatesCircleMembershipQueuesWithStableCursor() {
        InMemorySocialGraphRepository repository = repository(
                "owner_a",
                "join_new",
                "join_same",
                "join_old",
                "invite_user");
        SocialService service = service(repository);
        saveGroupWithOwner(repository, "target_group", "owner_a");
        saveGroupWithOwner(repository, "invite_group_new", "owner_a");
        saveGroupWithOwner(repository, "invite_group_same", "owner_a");
        saveGroupWithOwner(repository, "invite_group_old", "owner_a");
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "join_request_new",
                "target_group",
                "group",
                "join_new",
                "join_new",
                "join_request",
                "pending",
                "new",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "join_request_same",
                "target_group",
                "group",
                "join_same",
                "join_same",
                "join_request",
                "pending",
                "same timestamp",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "join_request_old",
                "target_group",
                "group",
                "join_old",
                "join_old",
                "join_request",
                "pending",
                "old",
                BASE_TIME.plusSeconds(30),
                BASE_TIME.plusSeconds(30)));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "invite_request_new",
                "invite_group_new",
                "group",
                "invite_user",
                "owner_a",
                "invite",
                "pending",
                "new",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "invite_request_same",
                "invite_group_same",
                "group",
                "invite_user",
                "owner_a",
                "invite",
                "pending",
                "same timestamp",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveCircleMembershipRequest(new CircleMembershipRequestRecord(
                "invite_request_old",
                "invite_group_old",
                "group",
                "invite_user",
                "owner_a",
                "invite",
                "pending",
                "old",
                BASE_TIME.plusSeconds(30),
                BASE_TIME.plusSeconds(30)));

        CircleMembershipRequestListResponse firstTargetPage = service.groupJoinRequests(
                        "target_group",
                        "owner_a",
                        "pending",
                        1,
                        "")
                .await().indefinitely();
        CircleMembershipRequestListResponse secondTargetPage = service.groupJoinRequests(
                        "target_group",
                        "owner_a",
                        "pending",
                        1,
                        firstTargetPage.nextCursor())
                .await().indefinitely();
        CircleMembershipRequestListResponse thirdTargetPage = service.groupJoinRequests(
                        "target_group",
                        "owner_a",
                        "pending",
                        1,
                        secondTargetPage.nextCursor())
                .await().indefinitely();
        CircleMembershipRequestListResponse firstUserInvitePage = service.userCircleInvites(
                        "invite_user",
                        "pending",
                        1,
                        "")
                .await().indefinitely();
        CircleMembershipRequestListResponse secondUserInvitePage = service.userCircleInvites(
                        "invite_user",
                        "pending",
                        1,
                        firstUserInvitePage.nextCursor())
                .await().indefinitely();
        CircleMembershipRequestListResponse thirdUserInvitePage = service.userCircleInvites(
                        "invite_user",
                        "pending",
                        1,
                        secondUserInvitePage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("join_request_new"), circleRequestIds(firstTargetPage));
        assertTrue(firstTargetPage.hasMore());
        assertFalse(firstTargetPage.nextCursor().isBlank());
        assertEquals(List.of("join_request_same"), circleRequestIds(secondTargetPage));
        assertTrue(secondTargetPage.hasMore());
        assertFalse(secondTargetPage.nextCursor().isBlank());
        assertEquals(List.of("join_request_old"), circleRequestIds(thirdTargetPage));
        assertFalse(thirdTargetPage.hasMore());
        assertEquals("", thirdTargetPage.nextCursor());
        assertEquals(List.of("invite_request_new"), circleRequestIds(firstUserInvitePage));
        assertTrue(firstUserInvitePage.hasMore());
        assertEquals(List.of("invite_request_same"), circleRequestIds(secondUserInvitePage));
        assertTrue(secondUserInvitePage.hasMore());
        assertFalse(secondUserInvitePage.nextCursor().isBlank());
        assertEquals(List.of("invite_request_old"), circleRequestIds(thirdUserInvitePage));
        assertFalse(thirdUserInvitePage.hasMore());
        assertEquals("", thirdUserInvitePage.nextCursor());
    }

    @Test
    void paginatesCircleContentModerationWithStableCursor() {
        InMemorySocialGraphRepository repository = repository("owner_a");
        SocialService service = service(repository);
        saveGroupWithOwner(repository, "moderation_group", "owner_a");
        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_new",
                "content_new",
                "moderation_group",
                "group",
                "owner_a",
                "remove",
                "removed",
                "new",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_same",
                "content_same",
                "moderation_group",
                "group",
                "owner_a",
                "remove",
                "removed",
                "same timestamp",
                BASE_TIME.plusSeconds(40),
                BASE_TIME.plusSeconds(40)));
        repository.saveCircleContentModeration(new CircleContentModerationRecord(
                "moderation_old",
                "content_old",
                "moderation_group",
                "group",
                "owner_a",
                "remove",
                "removed",
                "old",
                BASE_TIME.plusSeconds(30),
                BASE_TIME.plusSeconds(30)));

        CircleContentModerationListResponse firstPage = service.groupContentModeration(
                        "moderation_group",
                        "owner_a",
                        "removed",
                        1,
                        "")
                .await().indefinitely();
        CircleContentModerationListResponse secondPage = service.groupContentModeration(
                        "moderation_group",
                        "owner_a",
                        "removed",
                        1,
                        firstPage.nextCursor())
                .await().indefinitely();
        CircleContentModerationListResponse thirdPage = service.groupContentModeration(
                        "moderation_group",
                        "owner_a",
                        "removed",
                        1,
                        secondPage.nextCursor())
                .await().indefinitely();

        assertEquals(List.of("moderation_new"), moderationIds(firstPage));
        assertTrue(firstPage.hasMore());
        assertFalse(firstPage.nextCursor().isBlank());
        assertEquals(List.of("moderation_same"), moderationIds(secondPage));
        assertTrue(secondPage.hasMore());
        assertFalse(secondPage.nextCursor().isBlank());
        assertEquals(List.of("moderation_old"), moderationIds(thirdPage));
        assertFalse(thirdPage.hasMore());
        assertEquals("", thirdPage.nextCursor());
    }

    private InMemorySocialGraphRepository repository(String... userIds) {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        for (String userId : userIds) {
            saveProfile(repository, userId);
        }
        return repository;
    }

    private SocialService service(InMemorySocialGraphRepository repository) {
        return new SocialService(repository, config(Map.of()));
    }

    private void saveGroupWithOwner(InMemorySocialGraphRepository repository, String groupId, String ownerId) {
        repository.saveGroup(new SocialGroupRecord(groupId, groupId, "private", BASE_TIME));
        repository.saveGroupMembership(new MembershipRecord(ownerId, groupId, "owner", BASE_TIME));
    }

    private void saveProfile(InMemorySocialGraphRepository repository, String userId) {
        repository.saveUserProfile(new SocialUserProfileRecord(
                userId,
                userId,
                userId,
                "",
                "",
                "",
                "",
                "public",
                BASE_TIME,
                BASE_TIME));
    }

    private List<String> friendIds(FriendListResponse response) {
        return response.friends().stream().map(SocialDtos.FriendSummary::userId).toList();
    }

    private List<String> followerIds(SocialUserFollowListResponse response) {
        return response.follows().stream().map(SocialDtos.SocialUserFollowResponse::followerId).toList();
    }

    private List<String> followedIds(SocialUserFollowListResponse response) {
        return response.follows().stream().map(SocialDtos.SocialUserFollowResponse::followedUserId).toList();
    }

    private List<String> blockedUserIds(BlockListResponse response) {
        return response.blocks().stream().map(SocialDtos.BlockResponse::blockedUserId).toList();
    }

    private List<String> muteTargetIds(SocialMuteListResponse response) {
        return response.mutes().stream().map(SocialDtos.SocialMuteResponse::targetId).toList();
    }

    private List<String> familySecondUserIds(FamilyLinkListResponse response) {
        return response.links().stream().map(SocialDtos.FamilyLinkResponse::secondUserId).toList();
    }

    private List<String> friendRequestIds(FriendRequestListResponse response) {
        return response.requests().stream().map(SocialDtos.FriendRequestResponse::id).toList();
    }

    private List<String> requestFollowerIds(SocialUserFollowRequestListResponse response) {
        return response.requests().stream().map(SocialDtos.SocialUserFollowResponse::followerId).toList();
    }

    private List<String> recommendationUserIds(SocialRecommendationsResponse response) {
        return response.recommendations().stream().map(SocialDtos.SocialRecommendationItem::userId).toList();
    }

    private List<String> searchResultIds(SocialSearchResponse response) {
        return response.results().stream().map(SocialDtos.SocialSearchResult::id).toList();
    }

    private List<String> membershipMemberIds(MembershipListResponse response) {
        return response.memberships().stream().map(SocialDtos.MembershipResponse::memberId).toList();
    }

    private List<String> membershipTargetIds(MembershipListResponse response) {
        return response.memberships().stream().map(SocialDtos.MembershipResponse::targetId).toList();
    }

    private List<String> groupIds(SocialGroupListResponse response) {
        return response.groups().stream().map(SocialDtos.SocialGroupResponse::groupId).toList();
    }

    private List<String> communityIds(SocialCommunityListResponse response) {
        return response.communities().stream().map(SocialDtos.SocialCommunityResponse::communityId).toList();
    }

    private List<String> circleRequestIds(CircleMembershipRequestListResponse response) {
        return response.requests().stream().map(SocialDtos.CircleMembershipRequestResponse::requestId).toList();
    }

    private List<String> moderationIds(CircleContentModerationListResponse response) {
        return response.records().stream().map(SocialDtos.CircleContentModerationResponse::moderationId).toList();
    }

    private Config config(Map<String, String> values) {
        return new Config() {
            @Override
            public <T> T getValue(String propertyName, Class<T> propertyType) {
                return getOptionalValue(propertyName, propertyType)
                        .orElseThrow(() -> new NoSuchElementException(propertyName));
            }

            @Override
            public ConfigValue getConfigValue(String propertyName) {
                String value = values.get(propertyName);
                return new ConfigValue() {
                    @Override
                    public String getName() {
                        return propertyName;
                    }

                    @Override
                    public String getValue() {
                        return value;
                    }

                    @Override
                    public String getRawValue() {
                        return value;
                    }

                    @Override
                    public String getSourceName() {
                        return value == null ? null : "test";
                    }

                    @Override
                    public int getSourceOrdinal() {
                        return value == null ? 0 : 100;
                    }
                };
            }

            @Override
            public <T> Optional<T> getOptionalValue(String propertyName, Class<T> propertyType) {
                String value = values.get(propertyName);
                if (value == null) {
                    return Optional.empty();
                }
                if (propertyType == Boolean.class) {
                    return Optional.of(propertyType.cast(Boolean.valueOf(value)));
                }
                if (propertyType == String.class) {
                    return Optional.of(propertyType.cast(value));
                }
                throw new IllegalArgumentException("Unsupported test config type: " + propertyType.getName());
            }

            @Override
            public Iterable<String> getPropertyNames() {
                return values.keySet();
            }

            @Override
            public Iterable<ConfigSource> getConfigSources() {
                return List.of();
            }

            @Override
            public <T> Optional<Converter<T>> getConverter(Class<T> forType) {
                return Optional.empty();
            }

            @Override
            public <T> T unwrap(Class<T> type) {
                throw new IllegalArgumentException("Unsupported test config unwrap: " + type.getName());
            }
        };
    }
}
