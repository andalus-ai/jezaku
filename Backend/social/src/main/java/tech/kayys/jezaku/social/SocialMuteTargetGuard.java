package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.util.Objects;

final class SocialMuteTargetGuard implements SocialRelationshipWriteModel.MuteTargetValidator {
    private final SocialGraphEntityResolver entityResolver;

    SocialMuteTargetGuard(SocialGraphEntityResolver entityResolver) {
        this.entityResolver = Objects.requireNonNull(entityResolver, "entityResolver");
    }

    @Override
    public void ensureTarget(String userId, String targetType, String targetId) {
        if ("user".equals(targetType)) {
            if (userId.equals(targetId)) {
                throw new BadRequestException("Cannot mute yourself");
            }
            return;
        }
        if ("group".equals(targetType)) {
            entityResolver.requireGroup(targetId);
            return;
        }
        if ("community".equals(targetType)) {
            entityResolver.requireCommunity(targetId);
            return;
        }
        throw new BadRequestException("targetType must be user, group, or community");
    }
}
