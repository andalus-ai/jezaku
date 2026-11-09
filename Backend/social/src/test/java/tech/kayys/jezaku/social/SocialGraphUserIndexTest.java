package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialGraphUserIndexTest {
    @Test
    void collectsSortedDistinctKnownUsersAcrossGraphSurfaces() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialGraphUserIndex index = new SocialGraphUserIndex(repository);
        Instant now = Instant.parse("2026-06-02T16:00:00Z");

        repository.saveFriendship("user_friend_b", "user_friend_a", now);
        repository.saveCloseFriend("user_close_owner", "user_close_friend", now);
        repository.saveFriendRequest(new FriendRequestRecord(
                "friend_request_a",
                "user_request_from",
                "user_request_to",
                "",
                "pending",
                now,
                now));
        repository.saveUserFollow(new SocialUserFollowRecord("user_follower", "user_followed", now));
        repository.saveUserFollowRequest(new SocialUserFollowRequestRecord(
                "user_pending_follower",
                "user_pending_followed",
                "pending",
                now,
                now));
        repository.saveUserProfile(new SocialUserProfileRecord(
                "user_profile",
                "profile",
                "Profile",
                "",
                "",
                "",
                "",
                "public",
                now,
                now));
        repository.saveBlock(new BlockRecord("user_blocker", "user_blocked", "", now));
        repository.saveMute(new SocialMuteRecord("user_muter", "user", "user_muted", "", now));
        repository.saveMute(new SocialMuteRecord("user_group_muter", "group", "group_noise", "", now));
        repository.saveFamilyLink(new FamilyLinkRecord("user_family_a", "user_family_b", "sibling", now));
        repository.saveGroupMembership(new MembershipRecord("user_group_member", "group_a", "member", now));
        repository.saveCommunityMembership(new MembershipRecord(
                "user_community_member",
                "community_a",
                "member",
                now));
        repository.saveTagFollow(new SocialTagFollowRecord("user_tag_follower", "citywalk", now));

        SocialContentRecord content = new SocialContentRecord(
                "content_a",
                "user_content_owner",
                "photo",
                "public",
                "",
                "",
                now);
        repository.saveContent(content);
        repository.saveReaction(new SocialReactionRecord(content.contentId(), "user_reactor", "like", now));
        repository.saveComment(new SocialCommentRecord(
                "comment_a",
                content.contentId(),
                "user_comment_author",
                "hello",
                "",
                now));
        repository.saveCommentReaction(new SocialCommentReactionRecord(
                "comment_a",
                "user_comment_reactor",
                "like",
                now));
        repository.saveSave(new SocialSaveRecord(content.contentId(), "user_saver", now));
        repository.saveShare(new SocialShareRecord("share_a", content.contentId(), "user_sharer", "", now));
        repository.saveContentHide(new SocialContentHideRecord(content.contentId(), "user_hider", "", now));
        repository.saveContentReport(new SocialContentReportRecord(
                "report_a",
                content.contentId(),
                "user_reporter",
                "spam",
                "",
                "open",
                now,
                now));
        repository.saveMention(new SocialMentionRecord(
                "mention_a",
                content.contentId(),
                "comment_a",
                "user_mention_actor",
                "user_mentioned",
                "comment",
                now));
        repository.saveActivity(new SocialActivityRecord(
                "activity_a",
                "content_liked",
                "user_activity_actor",
                "user_activity_recipient",
                content.contentId(),
                "",
                "",
                "",
                now,
                false));
        repository.saveAdCampaign(new SocialAdCampaignRecord(
                "campaign_a",
                "user_advertiser",
                "Campaign",
                "reach",
                "active",
                content.contentId(),
                "approved",
                "",
                now,
                "USD",
                10_000,
                now,
                now.plusSeconds(86_400),
                2,
                25,
                3,
                List.of("friend"),
                List.of("citywalk"),
                List.of("group_a"),
                List.of("community_a"),
                now,
                now));
        repository.saveAdEvent(new SocialAdEventRecord(
                "ad_event_a",
                "campaign_a",
                "user_advertiser",
                "user_ad_viewer",
                "impression",
                "feed",
                content.contentId(),
                now,
                now));

        Set<String> expected = Set.of(
                "user_ad_viewer",
                "user_advertiser",
                "user_activity_actor",
                "user_activity_recipient",
                "user_blocked",
                "user_blocker",
                "user_close_friend",
                "user_close_owner",
                "user_comment_author",
                "user_comment_reactor",
                "user_community_member",
                "user_content_owner",
                "user_family_a",
                "user_family_b",
                "user_followed",
                "user_follower",
                "user_friend_a",
                "user_friend_b",
                "user_group_member",
                "user_group_muter",
                "user_hider",
                "user_mention_actor",
                "user_mentioned",
                "user_muted",
                "user_muter",
                "user_pending_followed",
                "user_pending_follower",
                "user_profile",
                "user_reactor",
                "user_reporter",
                "user_request_from",
                "user_request_to",
                "user_saver",
                "user_sharer",
                "user_tag_follower");
        List<String> knownUsers = index.knownUserIds();

        assertEquals(expected, new LinkedHashSet<>(knownUsers));
        assertEquals(expected.size(), knownUsers.size());
        assertEquals(knownUsers.stream().sorted().toList(), knownUsers);
    }
}
