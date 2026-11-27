import 'package:jejaku/features/sync/outbox/outbox_entry.dart';

/// How long the outbox waits before trying a held frame again.
///
/// Deterministic (no jitter) so it can be tested; the runner adds a trigger of
/// its own on app resume, sign-in and a new capture, which is what makes the
/// frame go out promptly when the network comes back.
abstract final class OutboxBackoff {
  static const Duration firstRetry = Duration(seconds: 15);
  static const Duration longestRetry = Duration(minutes: 15);
  static const Duration reviewRetry = Duration(minutes: 5);

  /// The wait after the [attempts]th failed send (1 for the first failure),
  /// or null when the hold is not retried by itself.
  static Duration? delayFor(OutboxHold hold, int attempts) {
    if (!hold.retries) {
      return null;
    }
    if (hold == OutboxHold.awaitingReview) {
      return reviewRetry;
    }
    final step = attempts < 1 ? 0 : attempts - 1;
    // 15 s, 30 s, 60 s ... capped; the shift is bounded so it cannot overflow.
    final seconds = firstRetry.inSeconds * (1 << (step > 10 ? 10 : step));
    final delay = Duration(seconds: seconds);
    return delay > longestRetry ? longestRetry : delay;
  }
}
