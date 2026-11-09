package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.NotFoundException;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessDecision;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentAccessResponse;

import java.util.List;
import java.util.Objects;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialContentAccessReadModel {
    private final SocialContentGraphStore repository;
    private final SocialContentAccessResolver contentAccessResolver;
    private final int maxBatchSize;

    SocialContentAccessReadModel(
            SocialContentGraphStore repository,
            SocialContentAccessResolver contentAccessResolver,
            int maxBatchSize) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.contentAccessResolver = Objects.requireNonNull(contentAccessResolver, "contentAccessResolver");
        this.maxBatchSize = maxBatchSize;
    }

    SocialContentAccessResponse access(SocialContentAccessRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String viewer = requireText(request.viewerId(), "viewerId");
        List<SocialContentAccessDecision> decisions = SocialBatchIds.normalize(
                        request.contentIds(),
                        "contentIds",
                        maxBatchSize,
                        "items").stream()
                .map(contentId -> contentAccessResolver.decision(requireContent(contentId), viewer))
                .toList();
        List<String> visibleContentIds = decisions.stream()
                .filter(SocialContentAccessDecision::canView)
                .map(SocialContentAccessDecision::contentId)
                .toList();
        List<String> hiddenContentIds = decisions.stream()
                .filter(decision -> !decision.canView())
                .map(SocialContentAccessDecision::contentId)
                .toList();

        return new SocialContentAccessResponse(
                viewer,
                decisions.size(),
                visibleContentIds.size(),
                hiddenContentIds.size(),
                visibleContentIds,
                hiddenContentIds,
                decisions);
    }

    private SocialContentRecord requireContent(String contentId) {
        String normalizedContentId = requireText(contentId, "contentId");
        SocialContentRecord content = repository.content(normalizedContentId);
        if (content == null) {
            throw new NotFoundException("Content not found: " + normalizedContentId);
        }
        return content;
    }
}
