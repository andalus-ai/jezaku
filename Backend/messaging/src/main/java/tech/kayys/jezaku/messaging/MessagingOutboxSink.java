package tech.kayys.jezaku.messaging;

interface MessagingOutboxSink {
    void dispatch(MessagingOutboxEvent event);
}
