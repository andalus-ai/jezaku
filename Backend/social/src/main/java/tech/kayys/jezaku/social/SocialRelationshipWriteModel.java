package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import tech.kayys.jezaku.social.SocialDtos.BlockRequest;
import tech.kayys.jezaku.social.SocialDtos.FamilyLinkCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.FriendRequestCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialMuteRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowDecisionRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialUserFollowRequest;

import java.time.Instant;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.Supplier;

import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialRelationshipWriteModel {
    private static final Set<String> USER_FOLLOW_REQUEST_DECISIONS = Set.of("approve", "reject");
    private static final Set<String> MUTE_TARGET_TYPES = Set.of("user", "group", "community");

    private final SocialRelationshipGraphStore repository;
    private final SocialRelationshipPolicy relationshipPolicy;
    private final Function<String, SocialUserProfileRecord> profileLookup;
    private final SocialRelationshipActivityPublisher activityPublisher;
    private final MuteTargetValidator muteTargetValidator;
    private final Supplier<Instant> now;
    private final Supplier<String> friendRequestIds;

    SocialRelationshipWriteModel(
            SocialRelationshipGraphStore repository,
            SocialRelationshipPolicy relationshipPolicy,
            Function<String, SocialUserProfileRecord> profileLookup,
            Function<String, String> userLabel,
            ActivityRecorder activityRecorder,
            MuteTargetValidator muteTargetValidator) {
        this(
                repository,
                relationshipPolicy,
                profileLookup,
                userLabel,
                activityRecorder,
                muteTargetValidator,
                Instant::now,
                () -> "friend_request_" + UUID.randomUUID());
    }

    SocialRelationshipWriteModel(
            SocialRelationshipGraphStore repository,
            SocialRelationshipPolicy relationshipPolicy,
            Function<String, SocialUserProfileRecord> profileLookup,
            Function<String, String> userLabel,
            ActivityRecorder activityRecorder,
            MuteTargetValidator muteTargetValidator,
            Supplier<Instant> now,
            Supplier<String> friendRequestIds) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.relationshipPolicy = Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        this.profileLookup = Objects.requireNonNull(profileLookup, "profileLookup");
        this.activityPublisher = new SocialRelationshipActivityPublisher(userLabel, activityRecorder);
        this.muteTargetValidator = Objects.requireNonNull(muteTargetValidator, "muteTargetValidator");
        this.now = Objects.requireNonNull(now, "now");
        this.friendRequestIds = Objects.requireNonNull(friendRequestIds, "friendRequestIds");
    }

    FriendRequestRecord createFriendRequest(FriendRequestCreateRequest request) {
        requireBody(request);
        String fromUserId = requireText(request.fromUserId(), "fromUserId");
        String toUserId = requireText(request.toUserId(), "toUserId");
        if (fromUserId.equals(toUserId)) {
            throw new BadRequestException("Cannot send a friend request to yourself");
        }
        relationshipPolicy.ensureNotBlocked(fromUserId, toUserId);
        if (relationshipPolicy.friends(fromUserId, toUserId)) {
            throw conflict("Users are already friends");
        }
        FriendRequestRecord existing = relationshipPolicy.pendingFriendRequestBetween(fromUserId, toUserId);
        if (existing != null) {
            return existing;
        }
        Instant createdAt = now.get();
        FriendRequestRecord created = new FriendRequestRecord(
                friendRequestIds.get(),
                fromUserId,
                toUserId,
                optionalTrim(request.message(), ""),
                "pending",
                createdAt,
                createdAt);
        repository.saveFriendRequest(created);
        activityPublisher.friendRequestReceived(fromUserId, toUserId);
        return created;
    }

    FriendRequestRecord acceptFriendRequest(String requestId, String actorUserId) {
        FriendRequestRecord request = requireFriendRequest(requestId);
        requirePendingFriendRequest(request);
        String actor = requireText(actorUserId, "actorUserId");
        if (!actor.equals(request.toUserId())) {
            throw new ForbiddenException("Only the request recipient can accept");
        }
        relationshipPolicy.ensureNotBlocked(request.fromUserId(), request.toUserId());
        Instant acceptedAt = now.get();
        repository.saveFriendship(request.fromUserId(), request.toUserId(), acceptedAt);
        FriendRequestRecord accepted = request.withStatus("accepted", acceptedAt);
        repository.saveFriendRequest(accepted);
        activityPublisher.friendRequestAccepted(request.toUserId(), request.fromUserId());
        return accepted;
    }

    FriendRequestRecord declineFriendRequest(String requestId, String actorUserId) {
        FriendRequestRecord request = requireFriendRequest(requestId);
        requirePendingFriendRequest(request);
        String actor = requireText(actorUserId, "actorUserId");
        if (!actor.equals(request.toUserId())) {
            throw new ForbiddenException("Only the request recipient can decline");
        }
        FriendRequestRecord declined = request.withStatus("declined", now.get());
        repository.saveFriendRequest(declined);
        return declined;
    }

    CloseFriendRecord addCloseFriend(String userId, String friendId) {
        String owner = requireText(userId, "userId");
        String friend = requireText(friendId, "friendId");
        if (!relationshipPolicy.friends(owner, friend)) {
            throw conflict("Close friends must already be friends");
        }
        Instant createdAt = now.get();
        repository.saveCloseFriend(owner, friend, createdAt);
        return new CloseFriendRecord(owner, friend, createdAt);
    }

    void removeCloseFriend(String userId, String friendId) {
        repository.removeCloseFriend(requireText(userId, "userId"), requireText(friendId, "friendId"));
    }

    SocialUserFollowWriteResult followUser(String followedUserId, SocialUserFollowRequest request) {
        requireBody(request);
        String followed = requireText(followedUserId, "followedUserId");
        String follower = requireText(request.followerId(), "followerId");
        if (follower.equals(followed)) {
            throw new BadRequestException("Users cannot follow themselves");
        }
        relationshipPolicy.ensureNotBlocked(follower, followed);
        SocialUserFollowRecord existing = repository.userFollow(follower, followed);
        if (existing != null) {
            return SocialUserFollowWriteResult.follow(existing, follower);
        }
        SocialUserProfileRecord followedProfile = profileLookup.apply(followed);
        SocialUserFollowRequestRecord existingRequest = repository.userFollowRequest(follower, followed);
        if (relationshipPolicy.followRequiresApproval(follower, followed, followedProfile)) {
            if (existingRequest != null && "pending".equals(existingRequest.status())) {
                return SocialUserFollowWriteResult.request(existingRequest, follower);
            }
            Instant requestedAt = now.get();
            SocialUserFollowRequestRecord requestRecord = new SocialUserFollowRequestRecord(
                    follower,
                    followed,
                    "pending",
                    existingRequest == null ? requestedAt : existingRequest.createdAt(),
                    requestedAt);
            repository.saveUserFollowRequest(requestRecord);
            activityPublisher.followRequested(follower, followed);
            return SocialUserFollowWriteResult.request(requestRecord, follower);
        }
        SocialUserFollowRecord follow = new SocialUserFollowRecord(follower, followed, now.get());
        repository.saveUserFollow(follow);
        repository.removeUserFollowRequest(follower, followed);
        activityPublisher.userFollowed(follower, followed);
        return SocialUserFollowWriteResult.follow(follow, follower);
    }

    void unfollowUser(String followedUserId, String followerId) {
        String follower = requireText(followerId, "followerId");
        String followed = requireText(followedUserId, "followedUserId");
        repository.removeUserFollow(follower, followed);
        repository.removeUserFollowRequest(follower, followed);
    }

    SocialUserFollowWriteResult decideUserFollowRequest(
            String followedUserId,
            String followerId,
            SocialUserFollowDecisionRequest request) {
        requireBody(request);
        String followed = requireText(followedUserId, "followedUserId");
        String follower = requireText(followerId, "followerId");
        String actor = requireText(request.actorUserId(), "actorUserId");
        if (!actor.equals(followed)) {
            throw new ForbiddenException("Only the followed user can answer this follow request");
        }
        SocialUserFollowRequestRecord existing = repository.userFollowRequest(follower, followed);
        if (existing == null) {
            throw new NotFoundException("Follow request not found");
        }
        if (!"pending".equals(existing.status())) {
            throw conflict("Follow request is already " + existing.status());
        }
        relationshipPolicy.ensureNotBlocked(follower, followed);
        String decision = optionalChoice(
                request.decision(),
                "",
                USER_FOLLOW_REQUEST_DECISIONS,
                "decision",
                "decision must be approve or reject");
        Instant decidedAt = now.get();
        if ("approve".equals(decision)) {
            SocialUserFollowRecord follow = new SocialUserFollowRecord(follower, followed, decidedAt);
            repository.saveUserFollow(follow);
            repository.saveUserFollowRequest(existing.withStatus("accepted", decidedAt));
            activityPublisher.followAccepted(followed, follower);
            return SocialUserFollowWriteResult.follow(follow, actor);
        }
        SocialUserFollowRequestRecord rejected = existing.withStatus("rejected", decidedAt);
        repository.saveUserFollowRequest(rejected);
        activityPublisher.followRejected(followed, follower);
        return SocialUserFollowWriteResult.request(rejected, actor);
    }

    void removeFriend(String userId, String friendId) {
        String user = requireText(userId, "userId");
        String friend = requireText(friendId, "friendId");
        repository.removeFriendship(user, friend);
        repository.removeCloseFriend(user, friend);
        repository.removeCloseFriend(friend, user);
    }

    BlockRecord block(BlockRequest request) {
        requireBody(request);
        String userId = requireText(request.userId(), "userId");
        String blockedUserId = requireText(request.blockedUserId(), "blockedUserId");
        if (userId.equals(blockedUserId)) {
            throw new BadRequestException("Cannot block yourself");
        }
        BlockRecord block = new BlockRecord(
                userId,
                blockedUserId,
                optionalTrim(request.reason(), ""),
                now.get());
        repository.saveBlock(block);
        relationshipPolicy.removeRelationshipState(userId, blockedUserId);
        return block;
    }

    void unblock(String userId, String blockedUserId) {
        repository.removeBlock(requireText(userId, "userId"), requireText(blockedUserId, "blockedUserId"));
    }

    SocialMuteRecord mute(SocialMuteRequest request) {
        requireBody(request);
        String userId = requireText(request.userId(), "userId");
        String targetType = normalizedMuteTargetType(request.targetType());
        String targetId = requireText(request.targetId(), "targetId");
        muteTargetValidator.ensureTarget(userId, targetType, targetId);
        SocialMuteRecord existing = repository.mute(userId, targetType, targetId);
        SocialMuteRecord mute = new SocialMuteRecord(
                userId,
                targetType,
                targetId,
                optionalTextMaxLength(request.reason(), "", "reason", 500),
                existing == null ? now.get() : existing.createdAt());
        repository.saveMute(mute);
        return mute;
    }

    void unmute(String userId, String targetType, String targetId) {
        repository.removeMute(
                requireText(userId, "userId"),
                normalizedMuteTargetType(targetType),
                requireText(targetId, "targetId"));
    }

    FamilyLinkRecord createFamilyLink(FamilyLinkCreateRequest request) {
        requireBody(request);
        String firstUserId = requireText(request.firstUserId(), "firstUserId");
        String secondUserId = requireText(request.secondUserId(), "secondUserId");
        if (firstUserId.equals(secondUserId)) {
            throw new BadRequestException("Cannot create a family link to yourself");
        }
        relationshipPolicy.ensureNotBlocked(firstUserId, secondUserId);
        FamilyLinkRecord link = new FamilyLinkRecord(
                firstUserId,
                secondUserId,
                requireText(request.relationship(), "relationship"),
                now.get());
        repository.saveFamilyLink(link);
        return link;
    }

    void removeFamilyLink(String userId, String relativeId) {
        repository.removeFamilyLink(requireText(userId, "userId"), requireText(relativeId, "relativeId"));
    }

    private FriendRequestRecord requireFriendRequest(String requestId) {
        String normalizedRequestId = requireText(requestId, "requestId");
        FriendRequestRecord request = repository.friendRequest(normalizedRequestId);
        if (request == null) {
            throw new NotFoundException("Friend request not found: " + normalizedRequestId);
        }
        return request;
    }

    private void requirePendingFriendRequest(FriendRequestRecord request) {
        if (!"pending".equals(request.status())) {
            throw conflict("Friend request is already " + request.status());
        }
    }

    private String normalizedMuteTargetType(String targetType) {
        return optionalChoice(targetType, "", MUTE_TARGET_TYPES,
                "targetType", "targetType must be user, group, or community");
    }

    private void requireBody(Object request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
    }

    private WebApplicationException conflict(String message) {
        return new WebApplicationException(message, Response.Status.CONFLICT);
    }

    @FunctionalInterface
    interface ActivityRecorder {
        void record(
                String eventType,
                String actorUserId,
                String recipientUserId,
                String contentId,
                String commentId,
                String sourceType,
                String message);
    }

    @FunctionalInterface
    interface MuteTargetValidator {
        void ensureTarget(String userId, String targetType, String targetId);
    }

    record SocialUserFollowWriteResult(
            SocialUserFollowRecord follow,
            SocialUserFollowRequestRecord request,
            String viewerId) {
        SocialUserFollowWriteResult {
            if ((follow == null) == (request == null)) {
                throw new IllegalArgumentException("Exactly one follow result is required");
            }
            Objects.requireNonNull(viewerId, "viewerId");
        }

        static SocialUserFollowWriteResult follow(SocialUserFollowRecord follow, String viewerId) {
            return new SocialUserFollowWriteResult(Objects.requireNonNull(follow, "follow"), null, viewerId);
        }

        static SocialUserFollowWriteResult request(SocialUserFollowRequestRecord request, String viewerId) {
            return new SocialUserFollowWriteResult(null, Objects.requireNonNull(request, "request"), viewerId);
        }
    }
}
