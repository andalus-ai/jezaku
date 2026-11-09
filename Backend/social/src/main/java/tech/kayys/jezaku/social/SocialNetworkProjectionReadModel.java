package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialGraphEdge;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphNode;
import tech.kayys.jezaku.social.SocialDtos.SocialNetworkResponse;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;

final class SocialNetworkProjectionReadModel {
    private final SocialGraphRepository repository;
    private final SocialGraphTraversalIndex traversalIndex;
    private final Function<String, String> userLabel;

    SocialNetworkProjectionReadModel(SocialGraphRepository repository, Function<String, String> userLabel) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.traversalIndex = new SocialGraphTraversalIndex(this.repository);
        this.userLabel = Objects.requireNonNull(userLabel, "userLabel");
    }

    SocialNetworkResponse network(String userId, int maxDepth) {
        Map<String, SocialGraphNode> nodes = new HashMap<>();
        List<SocialGraphEdge> edges = new ArrayList<>();
        Set<String> edgeKeys = new HashSet<>();
        putNode(nodes, userNode(userId, 0, "self", 1.0));

        List<FriendConnection> directFriends = traversalIndex.friendConnections(userId);
        Set<String> directFriendIds = new HashSet<>(directFriends.stream()
                .map(FriendConnection::userId)
                .toList());
        for (FriendConnection friend : directFriends) {
            putNode(nodes, userNode(friend.userId(), 1, friend.closeFriend() ? "close_friend" : "friend",
                    friend.closeFriend() ? 1.2 : 1.0));
            addEdge(edges, edgeKeys, new SocialGraphEdge(
                    userId,
                    friend.userId(),
                    "friend",
                    friend.closeFriend() ? "close_friend" : "friend",
                    false,
                    friend.closeFriend() ? 1.2 : 1.0,
                    friend.since()));
        }

        if (maxDepth >= 2) {
            for (FriendConnection friend : directFriends) {
                for (FriendConnection secondHop : traversalIndex.friendConnections(friend.userId())) {
                    if (secondHop.userId().equals(userId)
                            || directFriendIds.contains(secondHop.userId())
                            || traversalIndex.blockedEitherWay(userId, secondHop.userId())) {
                        continue;
                    }
                    putNode(nodes, userNode(secondHop.userId(), 2, "friend_of_friend", 0.65));
                    addEdge(edges, edgeKeys, new SocialGraphEdge(
                            friend.userId(),
                            secondHop.userId(),
                            "friend",
                            "friend_of_friend",
                            false,
                            0.65,
                            secondHop.since()));
                }
            }
        }

        for (FamilyConnection family : traversalIndex.familyFor(userId)) {
            putNode(nodes, userNode(family.relativeId(), 1, "family", 1.15));
            addEdge(edges, edgeKeys, new SocialGraphEdge(
                    userId,
                    family.relativeId(),
                    "family",
                    family.relationship(),
                    false,
                    1.15,
                    family.createdAt()));
        }

        for (MembershipRecord membership : traversalIndex.membershipsFor(repository.groupMemberships(), userId)) {
            SocialGroupRecord group = repository.group(membership.targetId());
            putNode(nodes, new SocialGraphNode(
                    membership.targetId(),
                    "group",
                    group == null ? membership.targetId() : group.name(),
                    1,
                    "group",
                    0.7));
            addEdge(edges, edgeKeys, new SocialGraphEdge(
                    userId,
                    membership.targetId(),
                    "member_of",
                    membership.role(),
                    true,
                    0.7,
                    membership.createdAt()));
        }

        for (MembershipRecord membership : traversalIndex.membershipsFor(repository.communityMemberships(), userId)) {
            SocialCommunityRecord community = repository.community(membership.targetId());
            putNode(nodes, new SocialGraphNode(
                    membership.targetId(),
                    "community",
                    community == null ? membership.targetId() : community.name(),
                    1,
                    "community",
                    0.6));
            addEdge(edges, edgeKeys, new SocialGraphEdge(
                    userId,
                    membership.targetId(),
                    "member_of",
                    membership.role(),
                    true,
                    0.6,
                    membership.createdAt()));
        }

        List<SocialGraphNode> sortedNodes = nodes.values().stream()
                .sorted(Comparator.comparingInt(SocialGraphNode::depth)
                        .thenComparing(SocialGraphNode::nodeType)
                        .thenComparing(SocialGraphNode::id))
                .toList();
        List<SocialGraphEdge> sortedEdges = edges.stream()
                .sorted(Comparator.comparing(SocialGraphEdge::edgeType)
                        .thenComparing(SocialGraphEdge::fromId)
                        .thenComparing(SocialGraphEdge::toId)
                        .thenComparing(SocialGraphEdge::relation))
                .toList();

        return new SocialNetworkResponse(
                userId,
                maxDepth,
                sortedNodes.size(),
                sortedEdges.size(),
                directFriends.size(),
                traversalIndex.friendsOfFriends(userId).size(),
                traversalIndex.familyFor(userId).size(),
                traversalIndex.membershipsFor(repository.groupMemberships(), userId).size(),
                traversalIndex.membershipsFor(repository.communityMemberships(), userId).size(),
                sortedNodes,
                sortedEdges);
    }

    private SocialGraphNode userNode(String userId, int depth, String relation, double score) {
        return new SocialGraphNode(userId, "user", userLabel.apply(userId), depth, relation, score);
    }

    private void putNode(Map<String, SocialGraphNode> nodes, SocialGraphNode candidate) {
        SocialGraphNode existing = nodes.get(candidate.id());
        if (existing == null
                || candidate.depth() < existing.depth()
                || (candidate.depth() == existing.depth() && candidate.score() > existing.score())) {
            nodes.put(candidate.id(), candidate);
        }
    }

    private void addEdge(List<SocialGraphEdge> edges, Set<String> edgeKeys, SocialGraphEdge edge) {
        String key = edgeKey(edge);
        if (edgeKeys.add(key)) {
            edges.add(edge);
        }
    }

    private String edgeKey(SocialGraphEdge edge) {
        if (edge.directed()) {
            return edge.fromId() + "->" + edge.toId() + "|" + edge.edgeType() + "|" + edge.relation();
        }
        String first = edge.fromId().compareTo(edge.toId()) <= 0 ? edge.fromId() : edge.toId();
        String second = edge.fromId().compareTo(edge.toId()) <= 0 ? edge.toId() : edge.fromId();
        return first + "|" + second + "|" + edge.edgeType() + "|" + edge.relation();
    }

}
