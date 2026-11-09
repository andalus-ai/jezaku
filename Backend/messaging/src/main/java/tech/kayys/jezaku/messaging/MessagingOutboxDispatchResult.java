package tech.kayys.jezaku.messaging;

record MessagingOutboxDispatchResult(int scanned, int dispatched, int failed) {
}
