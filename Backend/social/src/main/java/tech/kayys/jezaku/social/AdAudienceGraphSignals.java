package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.List;
import java.util.Set;

interface AdAudienceGraphSignals {
    SocialRelationshipContextResponse relationshipContext(String advertiserId, String candidateUserId);

    boolean friendOfFriend(String advertiserId, String candidateUserId);

    List<String> sharedGroupIds(String advertiserId, String candidateUserId);

    List<String> sharedCommunityIds(String advertiserId, String candidateUserId);

    boolean candidateFollowsAdvertiser(String advertiserId, String candidateUserId);

    Set<String> userInterestTags(String userId);

    Set<String> userGroupIds(String userId);

    Set<String> userCommunityIds(String userId);

    int visibleContentCount(String advertiserId, String candidateUserId);

    String userLabel(String userId);
}
