package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialConnectionPathResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphEdge;
import tech.kayys.jezaku.social.SocialDtos.SocialGraphNode;

import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Queue;
import java.util.function.Function;

final class SocialConnectionPathReadModel {
    private final SocialGraphRepository repository;
    private final SocialGraphTraversalIndex traversalIndex;
    private final Function<String, String> userLabel;

    SocialConnectionPathReadModel(SocialGraphRepository repository, Function<String, String> userLabel) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.traversalIndex = new SocialGraphTraversalIndex(this.repository);
        this.userLabel = Objects.requireNonNull(userLabel, "userLabel");
    }

    SocialConnectionPathResponse path(String fromUserId, String toUserId, int maxDepth) {
        if (fromUserId.equals(toUserId)) {
            return new SocialConnectionPathResponse(
                    fromUserId,
                    toUserId,
                    true,
                    maxDepth,
                    0,
                    "self",
                    List.of(userNode(fromUserId, 0, "self", 1.0)),
                    List.of());
        }
        if (traversalIndex.blockedEitherWay(fromUserId, toUserId)) {
            return emptyConnectionPath(fromUserId, toUserId, maxDepth, "blocked");
        }

        Map<String, ConnectionPathState> visited = new HashMap<>();
        Queue<String> queue = new ArrayDeque<>();
        visited.put(fromUserId, new ConnectionPathState(fromUserId, null, null, 0));
        queue.add(fromUserId);

        while (!queue.isEmpty()) {
            String currentUserId = queue.remove();
            ConnectionPathState current = visited.get(currentUserId);
            if (current.depth() >= maxDepth) {
                continue;
            }
            for (SocialGraphEdge edge : connectionPathEdges(currentUserId, fromUserId)) {
                String nextUserId = edge.toId();
                if (visited.containsKey(nextUserId)) {
                    continue;
                }
                ConnectionPathState next = new ConnectionPathState(
                        nextUserId,
                        currentUserId,
                        edge,
                        current.depth() + 1);
                visited.put(nextUserId, next);
                if (nextUserId.equals(toUserId)) {
                    return toConnectionPathResponse(fromUserId, toUserId, maxDepth, next, visited);
                }
                queue.add(nextUserId);
            }
        }
        return emptyConnectionPath(fromUserId, toUserId, maxDepth, "not_connected");
    }

    private SocialConnectionPathResponse emptyConnectionPath(
            String fromUserId,
            String toUserId,
            int maxDepth,
            String relation) {
        return new SocialConnectionPathResponse(
                fromUserId,
                toUserId,
                false,
                maxDepth,
                -1,
                relation,
                List.of(userNode(fromUserId, 0, "self", 1.0)),
                List.of());
    }

    private SocialConnectionPathResponse toConnectionPathResponse(
            String fromUserId,
            String toUserId,
            int maxDepth,
            ConnectionPathState target,
            Map<String, ConnectionPathState> states) {
        List<ConnectionPathState> reversedStates = new ArrayList<>();
        ConnectionPathState cursor = target;
        while (cursor != null) {
            reversedStates.add(cursor);
            cursor = cursor.previousUserId() == null ? null : states.get(cursor.previousUserId());
        }

        List<SocialGraphNode> nodes = new ArrayList<>();
        List<SocialGraphEdge> edges = new ArrayList<>();
        for (int i = reversedStates.size() - 1; i >= 0; i--) {
            ConnectionPathState state = reversedStates.get(i);
            nodes.add(userNode(
                    state.userId(),
                    state.depth(),
                    pathNodeRelation(state, target),
                    Math.max(0.2, 1.0 - (state.depth() * 0.15))));
            if (state.edge() != null) {
                edges.add(state.edge());
            }
        }

        return new SocialConnectionPathResponse(
                fromUserId,
                toUserId,
                true,
                maxDepth,
                target.depth(),
                connectionPathRelation(edges),
                List.copyOf(nodes),
                List.copyOf(edges));
    }

    private String pathNodeRelation(ConnectionPathState state, ConnectionPathState target) {
        if (state.depth() == 0) {
            return "self";
        }
        return state.userId().equals(target.userId()) ? "target" : "connector";
    }

    private String connectionPathRelation(List<SocialGraphEdge> edges) {
        if (edges.isEmpty()) {
            return "self";
        }
        if (edges.size() > 1) {
            return "connected";
        }
        return switch (edges.getFirst().edgeType()) {
            case "friend" -> "friend";
            case "family" -> "family";
            case "shared_group" -> "shared_group";
            case "shared_community" -> "shared_community";
            default -> "connected";
        };
    }

    private List<SocialGraphEdge> connectionPathEdges(String userId, String viewerId) {
        Map<String, SocialGraphEdge> edgesByNeighbor = new HashMap<>();
        for (FriendConnection friend : traversalIndex.friendConnections(userId)) {
            putConnectionPathEdge(edgesByNeighbor, viewerId, userId, friend.userId(), new SocialGraphEdge(
                    userId,
                    friend.userId(),
                    "friend",
                    friend.closeFriend() ? "close_friend" : "friend",
                    false,
                    friend.closeFriend() ? 1.2 : 1.0,
                    friend.since()));
        }
        for (FamilyConnection family : traversalIndex.familyFor(userId)) {
            putConnectionPathEdge(edgesByNeighbor, viewerId, userId, family.relativeId(), new SocialGraphEdge(
                    userId,
                    family.relativeId(),
                    "family",
                    family.relationship(),
                    false,
                    1.15,
                    family.createdAt()));
        }
        addSharedMembershipPathEdges(
                edgesByNeighbor,
                viewerId,
                userId,
                repository.groupMemberships(),
                "shared_group",
                0.7);
        addSharedMembershipPathEdges(
                edgesByNeighbor,
                viewerId,
                userId,
                repository.communityMemberships(),
                "shared_community",
                0.6);
        return edgesByNeighbor.values().stream()
                .sorted(Comparator.comparingInt(this::connectionPathEdgePriority).reversed()
                        .thenComparing(SocialGraphEdge::toId)
                        .thenComparing(SocialGraphEdge::relation))
                .toList();
    }

    private void addSharedMembershipPathEdges(
            Map<String, SocialGraphEdge> edgesByNeighbor,
            String viewerId,
            String userId,
                List<MembershipRecord> memberships,
                String edgeType,
                double weight) {
        for (MembershipRecord userMembership : traversalIndex.membershipsFor(memberships, userId)) {
            memberships.stream()
                    .filter(membership -> membership.targetId().equals(userMembership.targetId()))
                    .filter(membership -> !membership.memberId().equals(userId))
                    .forEach(membership -> putConnectionPathEdge(
                            edgesByNeighbor,
                            viewerId,
                            userId,
                            membership.memberId(),
                            new SocialGraphEdge(
                                    userId,
                                    membership.memberId(),
                                    edgeType,
                                    userMembership.targetId(),
                                    false,
                                    weight,
                                    later(userMembership.createdAt(), membership.createdAt()))));
        }
    }

    private void putConnectionPathEdge(
            Map<String, SocialGraphEdge> edgesByNeighbor,
            String viewerId,
            String userId,
            String neighborUserId,
            SocialGraphEdge candidate) {
        if (neighborUserId.equals(userId)
                || traversalIndex.blockedEitherWay(userId, neighborUserId)
                || (!neighborUserId.equals(viewerId) && traversalIndex.blockedEitherWay(viewerId, neighborUserId))) {
            return;
        }
        SocialGraphEdge existing = edgesByNeighbor.get(neighborUserId);
        if (existing == null
                || connectionPathEdgePriority(candidate) > connectionPathEdgePriority(existing)
                || (connectionPathEdgePriority(candidate) == connectionPathEdgePriority(existing)
                && candidate.weight() > existing.weight())) {
            edgesByNeighbor.put(neighborUserId, candidate);
        }
    }

    private int connectionPathEdgePriority(SocialGraphEdge edge) {
        return switch (edge.edgeType()) {
            case "friend" -> 4;
            case "family" -> 3;
            case "shared_group" -> 2;
            case "shared_community" -> 1;
            default -> 0;
        };
    }

    private SocialGraphNode userNode(String userId, int depth, String relation, double score) {
        return new SocialGraphNode(userId, "user", userLabel.apply(userId), depth, relation, score);
    }

    private Instant later(Instant first, Instant second) {
        return first.isAfter(second) ? first : second;
    }

    private record ConnectionPathState(
            String userId,
            String previousUserId,
            SocialGraphEdge edge,
            int depth) {
    }
}
