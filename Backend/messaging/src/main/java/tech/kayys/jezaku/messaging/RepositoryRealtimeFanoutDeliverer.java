package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;

@ApplicationScoped
public class RepositoryRealtimeFanoutDeliverer implements MessagingFanoutDeliverer {
    @Inject
    MessagingRepository repository;

    @Override
    public String target() {
        return MessagingSchema.FANOUT_TARGET_REALTIME;
    }

    @Override
    public void deliver(MessagingFanoutEnvelope envelope) {
        repository.saveFanoutTargetDelivery(
                MessagingFanoutTargetDeliveryFactory.from(envelope, target(), Instant.now()));
    }
}
