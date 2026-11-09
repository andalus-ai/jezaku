package tech.kayys.jezaku.messaging;

interface MessagingNotificationHandoffClient {
    void handoff(MessagingFanoutTargetDelivery delivery);
}
