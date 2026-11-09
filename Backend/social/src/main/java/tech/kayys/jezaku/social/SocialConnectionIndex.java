package tech.kayys.jezaku.social;

import java.util.Objects;

final class SocialConnectionIndex {
    private final SocialGraphRepository repository;
    private final SocialGraphTraversalIndex traversalIndex;

    SocialConnectionIndex(SocialGraphRepository repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.traversalIndex = new SocialGraphTraversalIndex(this.repository);
    }

    boolean friendOfFriend(String userId, String candidateUserId) {
        return traversalIndex.friendsOfFriends(userId).contains(candidateUserId);
    }

    boolean candidateFollows(String followedUserId, String candidateUserId) {
        return repository.followers(followedUserId).stream()
                .anyMatch(follow -> follow.followerId().equals(candidateUserId));
    }
}
