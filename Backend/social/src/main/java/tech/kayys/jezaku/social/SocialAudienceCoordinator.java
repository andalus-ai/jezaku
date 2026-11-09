package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceAccessResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionBatchResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudienceDecisionResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialAudiencePreviewResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialRelationshipContextResponse;

import java.util.Objects;
import java.util.function.BiFunction;

/**
 * Coordinates audience preview, visibility decision, and audience access endpoint workflows.
 */
final class SocialAudienceCoordinator {
    private static final int DEFAULT_PREVIEW_LIMIT = 100;
    private static final int DEFAULT_DECISION_BATCH_SIZE = 100;
    private static final int DEFAULT_ACCESS_BATCH_SIZE = 100;

    private final SocialAudienceDecisionPlanner decisionPlanner;
    private final SocialAudienceReadModel readModel;

    SocialAudienceCoordinator(
            SocialGraphRepository repository,
            SocialRelationshipPolicy relationshipPolicy,
            SocialCircleMembershipIndex circleMembershipIndex,
            BiFunction<String, String, SocialRelationshipContextResponse> relationshipContext,
            Limits limits) {
        SocialGraphRepository resolvedRepository = Objects.requireNonNull(repository, "repository");
        SocialRelationshipPolicy resolvedRelationshipPolicy =
                Objects.requireNonNull(relationshipPolicy, "relationshipPolicy");
        SocialCircleMembershipIndex resolvedCircleMembershipIndex =
                Objects.requireNonNull(circleMembershipIndex, "circleMembershipIndex");
        BiFunction<String, String, SocialRelationshipContextResponse> resolvedRelationshipContext =
                Objects.requireNonNull(relationshipContext, "relationshipContext");
        Limits resolvedLimits = Objects.requireNonNull(limits, "limits");

        this.decisionPlanner = new SocialAudienceDecisionPlanner(
                resolvedRepository,
                resolvedRelationshipContext::apply);
        SocialAudiencePreviewReadModel previewReadModel = new SocialAudiencePreviewReadModel(
                resolvedRepository,
                resolvedRelationshipPolicy,
                resolvedCircleMembershipIndex,
                resolvedRelationshipContext);
        this.readModel = new SocialAudienceReadModel(
                resolvedRepository,
                previewReadModel,
                decisionPlanner,
                resolvedLimits.previewLimit(),
                resolvedLimits.decisionBatchSize(),
                resolvedLimits.accessBatchSize());
    }

    SocialAudiencePreviewResponse preview(String ownerId, String scope, String targetId, Integer limit) {
        return readModel.preview(ownerId, scope, targetId, limit);
    }

    SocialAudienceDecisionResponse decision(String ownerId, String viewerId, String scope, String targetId) {
        return readModel.decision(ownerId, viewerId, scope, targetId);
    }

    SocialAudienceDecisionBatchResponse decisions(SocialAudienceDecisionBatchRequest request) {
        return readModel.decisions(request);
    }

    SocialAudienceAccessResponse access(SocialAudienceAccessRequest request) {
        return readModel.access(request);
    }

    SocialAudienceDecisionResponse decisionFor(String ownerId, String viewerId, String scope, String targetId) {
        return decisionPlanner.decision(ownerId, viewerId, scope, targetId);
    }

    static Limits defaultLimits() {
        return new Limits(
                DEFAULT_PREVIEW_LIMIT,
                DEFAULT_DECISION_BATCH_SIZE,
                DEFAULT_ACCESS_BATCH_SIZE);
    }

    /**
     * Defines audience preview and batch-size limits for audience endpoint orchestration.
     */
    record Limits(int previewLimit, int decisionBatchSize, int accessBatchSize) {
    }
}
