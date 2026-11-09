package tech.kayys.jezaku.messaging;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

import java.time.Instant;

@ApplicationScoped
public class RepositoryNotificationFanoutDeliverer implements MessagingFanoutDeliverer {
    @Inject
    MessagingRepository repository;

    @Inject
    MessagingNotificationHandoffClient handoffClient;

    @Override
    public String target() {
        return MessagingSchema.FANOUT_TARGET_NOTIFICATION;
    }

    @Override
    public void deliver(MessagingFanoutEnvelope envelope) {
        Instant now = Instant.now();
        MessagingFanoutTargetDelivery delivery =
                MessagingFanoutTargetDeliveryFactory.from(envelope, target(), now);
        MessagingFanoutTargetDelivery existing = repository.findFanoutTargetDeliveryById(delivery.deliveryId());
        if (existing != null
                && MessagingSchema.FANOUT_TARGET_DELIVERY_STATUS_ACKNOWLEDGED.equals(existing.status())) {
            return;
        }
        repository.saveFanoutTargetDelivery(delivery);
        handoffClient.handoff(delivery);
        repository.saveFanoutTargetDelivery(delivery.markAcknowledged(Instant.now()));
    }
}
