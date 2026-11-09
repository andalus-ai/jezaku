package tech.kayys.jezaku.social;

import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentUpdateRequest;

import java.util.Objects;

final class SocialContentLifecycleEndpointWriteModel {
    private final SocialContentLifecycleWriteModel writeModel;
    private final SocialContentPresentationResolver presentationResolver;

    SocialContentLifecycleEndpointWriteModel(
            SocialContentLifecycleWriteModel writeModel,
            SocialContentPresentationResolver presentationResolver) {
        this.writeModel = Objects.requireNonNull(writeModel, "writeModel");
        this.presentationResolver = Objects.requireNonNull(presentationResolver, "presentationResolver");
    }

    SocialContentResponse createContent(SocialContentCreateRequest request) {
        SocialContentRecord content = writeModel.createContent(request);
        return presentationResolver.content(content, content.ownerId());
    }

    SocialContentResponse updateContent(String contentId, SocialContentUpdateRequest request) {
        SocialContentRecord content = writeModel.updateContent(contentId, request);
        return presentationResolver.content(content, content.ownerId());
    }

    void deleteContent(String contentId, String actorUserId) {
        writeModel.deleteContent(contentId, actorUserId);
    }
}
