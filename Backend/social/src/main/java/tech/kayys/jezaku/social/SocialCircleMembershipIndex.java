package tech.kayys.jezaku.social;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

final class SocialCircleMembershipIndex {
    private final SocialCircleGraphStore repository;

    SocialCircleMembershipIndex(SocialCircleGraphStore repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    boolean groupMember(String userId, String groupId) {
        return memberOf(repository.groupMemberships(), userId, groupId);
    }

    boolean communityMember(String userId, String communityId) {
        return memberOf(repository.communityMemberships(), userId, communityId);
    }

    Set<String> groupIdsFor(String userId) {
        return targetIdsFor(repository.groupMemberships(), userId);
    }

    Set<String> communityIdsFor(String userId) {
        return targetIdsFor(repository.communityMemberships(), userId);
    }

    List<String> sharedGroupIds(String firstUserId, String secondUserId) {
        return sharedTargetIds(repository.groupMemberships(), firstUserId, secondUserId);
    }

    List<String> sharedCommunityIds(String firstUserId, String secondUserId) {
        return sharedTargetIds(repository.communityMemberships(), firstUserId, secondUserId);
    }

    List<String> groupMemberIdsExcept(String ownerId, String groupId) {
        return memberIdsExcept(repository.groupMemberships(), ownerId, groupId);
    }

    List<String> communityMemberIdsExcept(String ownerId, String communityId) {
        return memberIdsExcept(repository.communityMemberships(), ownerId, communityId);
    }

    private boolean memberOf(List<MembershipRecord> memberships, String memberId, String targetId) {
        return memberships.stream()
                .anyMatch(membership -> membership.memberId().equals(memberId)
                        && membership.targetId().equals(targetId));
    }

    private List<String> sharedTargetIds(List<MembershipRecord> memberships, String firstUserId, String secondUserId) {
        if (firstUserId.equals(secondUserId)) {
            return List.of();
        }
        Set<String> firstTargets = targetIdsFor(memberships, firstUserId);
        return memberships.stream()
                .filter(membership -> membership.memberId().equals(secondUserId))
                .map(MembershipRecord::targetId)
                .filter(firstTargets::contains)
                .distinct()
                .sorted()
                .toList();
    }

    private Set<String> targetIdsFor(List<MembershipRecord> memberships, String userId) {
        return new HashSet<>(memberships.stream()
                .filter(membership -> membership.memberId().equals(userId))
                .map(MembershipRecord::targetId)
                .toList());
    }

    private List<String> memberIdsExcept(List<MembershipRecord> memberships, String ownerId, String targetId) {
        return memberships.stream()
                .filter(membership -> membership.targetId().equals(targetId))
                .map(MembershipRecord::memberId)
                .filter(memberId -> !memberId.equals(ownerId))
                .distinct()
                .sorted()
                .toList();
    }
}
