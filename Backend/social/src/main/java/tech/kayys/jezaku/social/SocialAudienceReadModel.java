package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;

import java.util.List;
import java.util.Objects;
import java.util.Set;

import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialAudienceReadModel {
    private static final int DEFAULT_PREVIEW_LIMIT = 50;
    private static final Set<String> AUDIENCE_SCOPES = Set.of(
            "public",
            "private",
            "friends",
            "close_friends",
            "family",
            "group",
            "community");

    private final SocialGraphRepository repository;
    private final SocialAudiencePreviewReadModel previewReadModel;
    private final SocialAudienceDecisionPlanner decisionPlanner;
    private final int maxPreviewLimit;
    private final int maxDecisionBatchSize;
    private final int maxAccessBatchSize;

    SocialAudienceReadModel(
            SocialGraphRepository repository,
            SocialAudiencePreviewReadModel previewReadModel,
            SocialAudienceDecisionPlanner decisionPlanner,
            int maxPreviewLimit,
            int maxDecisionBatchSize,
            int maxAccessBatchSize) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.previewReadModel = Objects.requireNonNull(previewReadModel, "previewReadModel");
        this.decisionPlanner = Objects.requireNonNull(decisionPlanner, "decisionPlanner");
        this.maxPreviewLimit = maxPreviewLimit;
        this.maxDecisionBatchSize = maxDecisionBatchSize;
        this.maxAccessBatchSize = maxAccessBatchSize;
    }

    SocialAudiencePreviewResponse preview(String ownerId, String scope, String targetId, Integer limit) {
        String owner = requireText(ownerId, "ownerId");
        String normalizedScope = audienceScope(scope);
        int normalizedLimit = normalizeBoundedInt(limit, DEFAULT_PREVIEW_LIMIT, 1, maxPreviewLimit, "limit");
        String normalizedTargetId = previewTarget(normalizedScope, optionalTrim(targetId, ""));
        return previewReadModel.preview(owner, normalizedScope, normalizedTargetId, normalizedLimit);
    }

    SocialAudienceDecisionResponse decision(String ownerId, String viewerId, String scope, String targetId) {
        String owner = requireText(ownerId, "ownerId");
        String viewer = requireText(viewerId, "viewerId");
        String normalizedScope = audienceScope(scope);
        return decisionPlanner.decision(owner, viewer, normalizedScope, optionalTrim(targetId, ""));
    }

    SocialAudienceDecisionBatchResponse decisions(SocialAudienceDecisionBatchRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String owner = requireText(request.ownerId(), "ownerId");
        String normalizedScope = audienceScope(request.scope());
        String normalizedTargetId = optionalTrim(request.targetId(), "");
        List<SocialAudienceDecisionResponse> decisions = SocialBatchIds.normalize(
                        request.viewerIds(),
                        "viewerIds",
                        maxDecisionBatchSize,
                        "users").stream()
                .map(viewerId -> decisionPlanner.decision(owner, viewerId, normalizedScope, normalizedTargetId))
                .toList();

        return new SocialAudienceDecisionBatchResponse(
                owner,
                normalizedScope,
                normalizedTargetId,
                decisions.size(),
                decisions);
    }

    SocialAudienceAccessResponse access(SocialAudienceAccessRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String viewer = requireText(request.viewerId(), "viewerId");
        String normalizedScope = audienceScope(request.scope());
        String normalizedTargetId = optionalTrim(request.targetId(), "");
        List<SocialAudienceDecisionResponse> decisions = SocialBatchIds.normalize(
                        request.ownerIds(),
                        "ownerIds",
                        maxAccessBatchSize,
                        "users").stream()
                .map(ownerId -> decisionPlanner.decision(ownerId, viewer, normalizedScope, normalizedTargetId))
                .toList();
        List<String> allowedOwnerIds = decisions.stream()
                .filter(SocialAudienceDecisionResponse::canView)
                .map(SocialAudienceDecisionResponse::ownerId)
                .toList();
        List<String> deniedOwnerIds = decisions.stream()
                .filter(decision -> !decision.canView())
                .map(SocialAudienceDecisionResponse::ownerId)
                .toList();

        return new SocialAudienceAccessResponse(
                viewer,
                normalizedScope,
                normalizedTargetId,
                decisions.size(),
                allowedOwnerIds.size(),
                deniedOwnerIds.size(),
                allowedOwnerIds,
                deniedOwnerIds,
                decisions);
    }

    private String previewTarget(String scope, String targetId) {
        if ("group".equals(scope)) {
            return requireGroup(requireAudienceTarget(targetId, "group")).groupId();
        }
        if ("community".equals(scope)) {
            return requireCommunity(requireAudienceTarget(targetId, "community")).communityId();
        }
        return "";
    }

    private String audienceScope(String scope) {
        return optionalChoice(
                scope,
                "friends",
                AUDIENCE_SCOPES,
                "scope",
                "scope must be public, private, friends, close_friends, family, group, or community");
    }

    private String requireAudienceTarget(String targetId, String scope) {
        return requireText(targetId, "targetId for " + scope + " audience");
    }

    private SocialGroupRecord requireGroup(String groupId) {
        String normalizedGroupId = requireText(groupId, "groupId");
        SocialGroupRecord group = repository.group(normalizedGroupId);
        if (group == null) {
            throw new NotFoundException("Group not found: " + normalizedGroupId);
        }
        return group;
    }

    private SocialCommunityRecord requireCommunity(String communityId) {
        String normalizedCommunityId = requireText(communityId, "communityId");
        SocialCommunityRecord community = repository.community(normalizedCommunityId);
        if (community == null) {
            throw new NotFoundException("Community not found: " + normalizedCommunityId);
        }
        return community;
    }
}
