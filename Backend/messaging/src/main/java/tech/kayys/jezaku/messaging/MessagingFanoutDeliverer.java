package tech.kayys.jezaku.messaging;

interface MessagingFanoutDeliverer {
    String target();

    void deliver(MessagingFanoutEnvelope envelope);
}
