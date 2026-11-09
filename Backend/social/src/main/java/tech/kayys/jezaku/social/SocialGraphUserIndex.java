package tech.kayys.jezaku.social;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;

final class SocialGraphUserIndex {
    private final SocialGraphRepository repository;

    SocialGraphUserIndex(SocialGraphRepository repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    List<String> knownUserIds() {
        LinkedHashSet<String> userIds = new LinkedHashSet<>();
        repository.friendships().forEach(friendship -> {
            userIds.add(friendship.firstUserId());
            userIds.add(friendship.secondUserId());
        });
        repository.closeFriends().forEach(closeFriend -> {
            userIds.add(closeFriend.ownerId());
            userIds.add(closeFriend.friendId());
        });
        repository.friendRequests().forEach(request -> {
            userIds.add(request.fromUserId());
            userIds.add(request.toUserId());
        });
        repository.userFollows().forEach(follow -> {
            userIds.add(follow.followerId());
            userIds.add(follow.followedUserId());
        });
        repository.userFollowRequests().forEach(request -> {
            userIds.add(request.followerId());
            userIds.add(request.followedUserId());
        });
        repository.userProfiles().stream().map(SocialUserProfileRecord::userId).forEach(userIds::add);
        repository.blocks().forEach(block -> {
            userIds.add(block.userId());
            userIds.add(block.blockedUserId());
        });
        repository.mutes().forEach(mute -> {
            userIds.add(mute.userId());
            if ("user".equals(mute.targetType())) {
                userIds.add(mute.targetId());
            }
        });
        repository.familyLinks().forEach(link -> {
            userIds.add(link.firstUserId());
            userIds.add(link.secondUserId());
        });
        repository.groupMemberships().stream().map(MembershipRecord::memberId).forEach(userIds::add);
        repository.communityMemberships().stream().map(MembershipRecord::memberId).forEach(userIds::add);
        repository.tagFollows().stream().map(SocialTagFollowRecord::userId).forEach(userIds::add);
        repository.contents().forEach(content -> {
            userIds.add(content.ownerId());
            repository.reactions(content.contentId()).stream().map(SocialReactionRecord::userId).forEach(userIds::add);
            repository.comments(content.contentId()).forEach(comment -> {
                userIds.add(comment.authorId());
                repository.commentReactions(comment.commentId()).stream()
                        .map(SocialCommentReactionRecord::userId)
                        .forEach(userIds::add);
            });
            repository.saves(content.contentId()).stream().map(SocialSaveRecord::userId).forEach(userIds::add);
            repository.shares(content.contentId()).stream().map(SocialShareRecord::userId).forEach(userIds::add);
            repository.contentHides(content.contentId()).stream()
                    .map(SocialContentHideRecord::userId)
                    .forEach(userIds::add);
            repository.mentions(content.contentId()).forEach(mention -> {
                userIds.add(mention.actorId());
                userIds.add(mention.mentionedUserId());
            });
        });
        repository.contentReports().stream().map(SocialContentReportRecord::reporterId).forEach(userIds::add);
        repository.activities().forEach(activity -> {
            userIds.add(activity.actorId());
            userIds.add(activity.recipientId());
        });
        repository.adCampaigns().stream().map(SocialAdCampaignRecord::advertiserId).forEach(userIds::add);
        repository.adEvents().forEach(event -> {
            userIds.add(event.advertiserId());
            userIds.add(event.viewerId());
        });
        return userIds.stream()
                .filter(userId -> userId != null && !userId.isBlank())
                .sorted()
                .toList();
    }
}
