package tech.kayys.jezaku.social;

import jakarta.ws.rs.NotFoundException;

import java.util.Objects;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialGraphEntityResolver {
    private final SocialGraphRepository repository;

    SocialGraphEntityResolver(SocialGraphRepository repository) {
        this.repository = Objects.requireNonNull(repository, "repository");
    }

    SocialGroupRecord requireGroup(String groupId) {
        String normalizedGroupId = requireText(groupId, "groupId");
        SocialGroupRecord group = repository.group(normalizedGroupId);
        if (group == null) {
            throw new NotFoundException("Group not found: " + normalizedGroupId);
        }
        return group;
    }

    SocialCommunityRecord requireCommunity(String communityId) {
        String normalizedCommunityId = requireText(communityId, "communityId");
        SocialCommunityRecord community = repository.community(normalizedCommunityId);
        if (community == null) {
            throw new NotFoundException("Community not found: " + normalizedCommunityId);
        }
        return community;
    }

    SocialContentRecord requireContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        SocialContentRecord content = repository.content(normalizedContentId);
        if (content == null) {
            throw new NotFoundException("Content not found: " + normalizedContentId);
        }
        return content;
    }
}
