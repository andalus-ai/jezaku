package tech.kayys.jezaku.social;

import java.util.Objects;
import java.util.function.Function;

/**
 * Publishes activity events caused by relationship graph changes such as friend requests, follows, and family links.
 */
final class SocialRelationshipActivityPublisher {
    private final Function<String, String> userLabel;
    private final SocialRelationshipWriteModel.ActivityRecorder activityRecorder;

    SocialRelationshipActivityPublisher(
            Function<String, String> userLabel,
            SocialRelationshipWriteModel.ActivityRecorder activityRecorder) {
        this.userLabel = Objects.requireNonNull(userLabel, "userLabel");
        this.activityRecorder = Objects.requireNonNull(activityRecorder, "activityRecorder");
    }

    void friendRequestReceived(String senderUserId, String recipientUserId) {
        record(
                "friend_request_received",
                senderUserId,
                recipientUserId,
                userLabel.apply(senderUserId) + " sent you a friend request.");
    }

    void friendRequestAccepted(String acceptingUserId, String requesterUserId) {
        record(
                "friend_request_accepted",
                acceptingUserId,
                requesterUserId,
                userLabel.apply(acceptingUserId) + " accepted your friend request.");
    }

    void followRequested(String followerUserId, String followedUserId) {
        record(
                "follow_requested",
                followerUserId,
                followedUserId,
                userLabel.apply(followerUserId) + " requested to follow you.");
    }

    void userFollowed(String followerUserId, String followedUserId) {
        record(
                "user_followed",
                followerUserId,
                followedUserId,
                userLabel.apply(followerUserId) + " followed you.");
    }

    void followAccepted(String followedUserId, String followerUserId) {
        record(
                "follow_accepted",
                followedUserId,
                followerUserId,
                userLabel.apply(followedUserId) + " accepted your follow request.");
    }

    void followRejected(String followedUserId, String followerUserId) {
        record(
                "follow_rejected",
                followedUserId,
                followerUserId,
                userLabel.apply(followedUserId) + " rejected your follow request.");
    }

    void familyLinkCreated(String userId, String relativeUserId, String relationship) {
        record(
                "family_link_created",
                userId,
                relativeUserId,
                userLabel.apply(userId) + " added you as " + relationship + ".");
    }

    private void record(String eventType, String actorUserId, String recipientUserId, String message) {
        activityRecorder.record(
                eventType,
                actorUserId,
                recipientUserId,
                "",
                "",
                "",
                message);
    }
}
