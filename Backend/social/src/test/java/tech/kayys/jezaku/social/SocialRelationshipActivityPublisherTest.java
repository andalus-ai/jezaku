package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialRelationshipActivityPublisherTest {
    @Test
    void publishesRelationshipActivityMessagesWithCanonicalEventTypes() {
        List<ActivityEvent> activities = new ArrayList<>();
        SocialRelationshipActivityPublisher publisher = new SocialRelationshipActivityPublisher(
                userId -> "Label " + userId,
                (eventType, actorUserId, recipientUserId, contentId, commentId, sourceType, message) ->
                        activities.add(new ActivityEvent(eventType, actorUserId, recipientUserId, message)));

        publisher.friendRequestReceived("sender", "recipient");
        publisher.friendRequestAccepted("recipient", "sender");
        publisher.followRequested("follower", "private_owner");
        publisher.userFollowed("follower", "public_owner");
        publisher.followAccepted("private_owner", "follower");
        publisher.followRejected("private_owner", "follower");

        assertEquals(List.of(
                new ActivityEvent(
                        "friend_request_received",
                        "sender",
                        "recipient",
                        "Label sender sent you a friend request."),
                new ActivityEvent(
                        "friend_request_accepted",
                        "recipient",
                        "sender",
                        "Label recipient accepted your friend request."),
                new ActivityEvent(
                        "follow_requested",
                        "follower",
                        "private_owner",
                        "Label follower requested to follow you."),
                new ActivityEvent(
                        "user_followed",
                        "follower",
                        "public_owner",
                        "Label follower followed you."),
                new ActivityEvent(
                        "follow_accepted",
                        "private_owner",
                        "follower",
                        "Label private_owner accepted your follow request."),
                new ActivityEvent(
                        "follow_rejected",
                        "private_owner",
                        "follower",
                        "Label private_owner rejected your follow request.")),
                activities);
    }

    private record ActivityEvent(String eventType, String actorUserId, String recipientUserId, String message) {
    }
}
