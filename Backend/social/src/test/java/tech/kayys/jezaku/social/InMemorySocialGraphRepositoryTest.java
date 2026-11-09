package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class InMemorySocialGraphRepositoryTest {
    @Test
    void storesUndirectedFriendshipsAndDirectedCloseFriends() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Instant now = Instant.parse("2026-06-01T08:00:00Z");

        repository.saveFriendship("user_b", "user_a", now);
        repository.saveCloseFriend("user_a", "user_b", now.plusSeconds(1));
        repository.saveUserFollow(new SocialUserFollowRecord("user_a", "user_c", now.plusSeconds(2)));

        assertTrue(repository.friendships().stream()
                .anyMatch(friendship -> samePair(friendship.firstUserId(), friendship.secondUserId(),
                        "user_a", "user_b")));
        assertEquals(1, repository.friendships().size());
        assertEquals(1, repository.closeFriends().size());
        assertEquals("user_a", repository.closeFriends().getFirst().ownerId());
        assertEquals("user_b", repository.closeFriends().getFirst().friendId());
        assertEquals(1, repository.userFollows().size());
        assertEquals("user_c", repository.following("user_a").getFirst().followedUserId());
        assertEquals("user_a", repository.followers("user_c").getFirst().followerId());
        assertEquals("user_c", repository.userFollow("user_a", "user_c").followedUserId());

        repository.removeFriendship("user_a", "user_b");
        repository.removeCloseFriend("user_a", "user_b");
        repository.removeUserFollow("user_a", "user_c");

        assertTrue(repository.friendships().isEmpty());
        assertTrue(repository.closeFriends().isEmpty());
        assertTrue(repository.following("user_a").isEmpty());
    }

    @Test
    void separatesBlocksGroupsCommunitiesAndRequests() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Instant now = Instant.parse("2026-06-01T08:30:00Z");

        FriendRequestRecord request = new FriendRequestRecord(
                "friend_request_test",
                "user_a",
                "user_b",
                "hello",
                "pending",
                now,
                now);
        repository.saveFriendRequest(request);
        SocialUserFollowRequestRecord followRequest = new SocialUserFollowRequestRecord(
                "user_b",
                "user_a",
                "pending",
                now,
                now);
        repository.saveUserFollowRequest(followRequest);
        SocialUserProfileRecord profile = new SocialUserProfileRecord(
                "user_a",
                "user_a",
                "User A",
                "Profile bio",
                "",
                "",
                "Bandung",
                "public",
                now,
                now);
        repository.saveUserProfile(profile);
        repository.saveBlock(new BlockRecord("user_a", "user_blocked", "unsafe", now));
        SocialMuteRecord mute = new SocialMuteRecord("user_a", "group", "group_creators", "too noisy", now);
        repository.saveMute(mute);
        repository.saveGroup(new SocialGroupRecord("group_creators", "Creators", "public", now));
        repository.saveGroupMembership(new MembershipRecord("user_a", "group_creators", "owner", now));
        repository.saveCommunity(new SocialCommunityRecord("community_city", "City", "public", now));
        repository.saveCommunityMembership(new MembershipRecord("user_a", "community_city", "member", now));
        CircleMembershipRequestRecord circleRequest = new CircleMembershipRequestRecord(
                "circle_request_test",
                "group_creators",
                "group",
                "user_b",
                "user_b",
                "join_request",
                "pending",
                "please add me",
                now,
                now);
        repository.saveCircleMembershipRequest(circleRequest);
        CircleContentModerationRecord moderation = new CircleContentModerationRecord(
                "moderation_test",
                "content_a",
                "group_creators",
                "group",
                "user_a",
                "remove",
                "removed",
                "off topic",
                now,
                now);
        repository.saveCircleContentModeration(moderation);

        assertEquals(request, repository.friendRequest("friend_request_test"));
        assertEquals(followRequest, repository.userFollowRequest("user_b", "user_a"));
        assertEquals(1, repository.userFollowRequests().size());
        assertEquals(profile, repository.userProfile("user_a"));
        assertEquals(profile, repository.userProfileByHandle("user_a"));
        assertEquals(1, repository.userProfiles().size());
        assertEquals("user_blocked", repository.blocks().getFirst().blockedUserId());
        assertEquals(mute, repository.mute("user_a", "group", "group_creators"));
        assertEquals(1, repository.mutesByUser("user_a").size());
        assertEquals("Creators", repository.group("group_creators").name());
        assertEquals("City", repository.community("community_city").name());
        assertEquals(1, repository.groupMemberships().size());
        assertEquals(1, repository.communityMemberships().size());
        assertEquals(circleRequest, repository.circleMembershipRequest("circle_request_test"));
        assertEquals(1, repository.circleMembershipRequests().size());
        assertEquals(moderation, repository.circleContentModeration("moderation_test"));
        assertEquals(1, repository.circleContentModerations().size());

        repository.removeFriendRequest("friend_request_test");
        repository.removeUserFollowRequest("user_b", "user_a");
        repository.removeBlock("user_a", "user_blocked");
        repository.removeMute("user_a", "group", "group_creators");
        repository.removeCircleMembershipRequest("circle_request_test");
        repository.removeCircleContentModerations("content_a");

        assertTrue(repository.friendRequests().isEmpty());
        assertTrue(repository.userFollowRequests().isEmpty());
        assertTrue(repository.circleMembershipRequests().isEmpty());
        assertTrue(repository.circleContentModerations().isEmpty());
        assertFalse(repository.blocks().stream()
                .anyMatch(block -> block.userId().equals("user_a") && block.blockedUserId().equals("user_blocked")));
        assertNull(repository.mute("user_a", "group", "group_creators"));
    }

    @Test
    void storesContentReactionsAndComments() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        Instant now = Instant.parse("2026-06-01T09:00:00Z");

        SocialContentRecord content = new SocialContentRecord(
                "content_a",
                "user_a",
                "photo",
                "friends",
                "",
                "hello",
                now);
        SocialReactionRecord firstReaction = new SocialReactionRecord(
                "content_a",
                "user_b",
                "like",
                now.plusSeconds(1));
        SocialReactionRecord updatedReaction = new SocialReactionRecord(
                "content_a",
                "user_b",
                "like",
                now.plusSeconds(2));
        SocialContentTagRecord tag = new SocialContentTagRecord(
                "content_a",
                "citywalk",
                now.plusSeconds(3));
        SocialTagFollowRecord tagFollow = new SocialTagFollowRecord(
                "user_b",
                "citywalk",
                now.plusSeconds(4));
        SocialCommentRecord comment = new SocialCommentRecord(
                "comment_a",
                "content_a",
                "user_b",
                "nice",
                "",
                now.plusSeconds(5));
        SocialCommentRecord reply = new SocialCommentRecord(
                "comment_b",
                "content_a",
                "user_c",
                "replying",
                "comment_a",
                now.plusSeconds(6));
        SocialCommentReactionRecord commentReaction = new SocialCommentReactionRecord(
                "comment_a",
                "user_c",
                "like",
                now.plusSeconds(7));
        SocialSaveRecord save = new SocialSaveRecord(
                "content_a",
                "user_b",
                now.plusSeconds(8));
        SocialShareRecord share = new SocialShareRecord(
                "share_a",
                "content_a",
                "user_b",
                "worth seeing",
                now.plusSeconds(8));
        SocialContentHideRecord hide = new SocialContentHideRecord(
                "content_a",
                "user_b",
                "not_interested",
                now.plusSeconds(9));
        SocialContentReportRecord report = new SocialContentReportRecord(
                "report_a",
                "content_a",
                "user_b",
                "spam",
                "too much",
                "open",
                now.plusSeconds(10),
                now.plusSeconds(10));
        SocialMentionRecord mention = new SocialMentionRecord(
                "mention_a",
                "content_a",
                "comment_a",
                "user_b",
                "user_c",
                "comment",
                now.plusSeconds(11));

        repository.saveContent(content);
        repository.saveReaction(firstReaction);
        repository.saveReaction(updatedReaction);
        repository.saveContentTag(tag);
        repository.saveTagFollow(tagFollow);
        repository.saveComment(comment);
        repository.saveComment(reply);
        repository.saveCommentReaction(commentReaction);
        repository.saveSave(save);
        repository.saveShare(share);
        repository.saveContentHide(hide);
        repository.saveContentReport(report);
        repository.saveMention(mention);
        SocialActivityRecord activity = new SocialActivityRecord(
                "activity_a",
                "content_liked",
                "user_b",
                "user_a",
                "content_a",
                "",
                "like",
                "",
                now.plusSeconds(12),
                false);
        repository.saveActivity(activity);
        SocialAdCampaignRecord campaign = new SocialAdCampaignRecord(
                "campaign_a",
                "user_a",
                "Campus Launch",
                "awareness",
                "draft",
                "content_a",
                "pending_review",
                "",
                null,
                "USD",
                25_000,
                now.plusSeconds(13),
                now.plusSeconds(86_400),
                2,
                25,
                3,
                List.of("friend_of_friend"),
                List.of("citywalk"),
                List.of("group_creators"),
                List.of("community_city"),
                now.plusSeconds(13),
                now.plusSeconds(13));
        repository.saveAdCampaign(campaign);
        SocialAdEventRecord adEvent = new SocialAdEventRecord(
                "ad_event_a",
                "campaign_a",
                "user_a",
                "user_b",
                "impression",
                "feed",
                "content_a",
                now.plusSeconds(14),
                now.plusSeconds(14));
        repository.saveAdEvent(adEvent);

        assertEquals(content, repository.content("content_a"));
        assertEquals(1, repository.reactions("content_a").size());
        assertEquals(updatedReaction, repository.reaction("content_a", "user_b"));
        assertEquals(tag, repository.contentTags("content_a").getFirst());
        assertEquals(tag, repository.taggedContent("citywalk").getFirst());
        assertEquals(1, repository.tags().size());
        assertEquals(tagFollow, repository.tagFollow("user_b", "citywalk"));
        assertEquals(1, repository.tagFollows().size());
        assertEquals(1, repository.tagFollows("citywalk").size());
        assertEquals(1, repository.tagFollowsByUser("user_b").size());
        assertEquals(comment, repository.comment("comment_a"));
        assertEquals(2, repository.comments("content_a").size());
        assertEquals("comment_a", repository.comment("comment_b").parentCommentId());
        assertEquals(commentReaction, repository.commentReaction("comment_a", "user_c"));
        assertEquals(1, repository.commentReactions("comment_a").size());
        assertEquals(save, repository.save("content_a", "user_b"));
        assertEquals(1, repository.saves("content_a").size());
        assertEquals(1, repository.savedByUser("user_b").size());
        assertEquals(share, repository.share("share_a"));
        assertEquals(1, repository.shares("content_a").size());
        assertEquals(hide, repository.contentHide("content_a", "user_b"));
        assertEquals(1, repository.contentHides("content_a").size());
        assertEquals(1, repository.hiddenByUser("user_b").size());
        assertEquals(report, repository.contentReport("report_a"));
        assertEquals(1, repository.contentReports().size());
        assertEquals(1, repository.mentions("content_a").size());
        assertEquals(mention, repository.mentionsForUser("user_c").getFirst());
        assertEquals(activity, repository.activity("activity_a"));
        assertEquals(campaign, repository.adCampaign("campaign_a"));
        assertEquals(1, repository.adCampaigns().size());
        assertEquals(adEvent, repository.adEvent("ad_event_a"));
        assertEquals(1, repository.adEvents().size());

        repository.removeReaction("content_a", "user_b");
        repository.removeContentTags("content_a");
        repository.removeTagFollow("user_b", "citywalk");
        repository.removeComment("comment_a");
        repository.removeComment("comment_b");
        repository.removeCommentReaction("comment_a", "user_c");
        repository.removeSave("content_a", "user_b");
        repository.removeShare("share_a");
        repository.removeContentHide("content_a", "user_b");
        repository.removeContentReports("content_a");
        repository.removeMentionsForComment("comment_a");
        repository.removeMentionsForContent("content_a");
        repository.saveActivity(activity.withRead(true));
        repository.removeActivitiesForContent("content_a");
        repository.removeContent("content_a");

        assertTrue(repository.reactions("content_a").isEmpty());
        assertTrue(repository.contentTags("content_a").isEmpty());
        assertTrue(repository.tagFollowsByUser("user_b").isEmpty());
        assertTrue(repository.comments("content_a").isEmpty());
        assertTrue(repository.commentReactions("comment_a").isEmpty());
        assertTrue(repository.saves("content_a").isEmpty());
        assertTrue(repository.shares("content_a").isEmpty());
        assertTrue(repository.contentHides("content_a").isEmpty());
        assertTrue(repository.contentReports().isEmpty());
        assertTrue(repository.mentions("content_a").isEmpty());
        assertNull(repository.activity("activity_a"));
        assertNull(repository.content("content_a"));
    }

    private boolean samePair(String a, String b, String c, String d) {
        return (a.equals(c) && b.equals(d)) || (a.equals(d) && b.equals(c));
    }
}
