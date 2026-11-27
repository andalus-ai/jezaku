import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';

/// What the person should be told about a frame waiting in the outbox, in
/// words, and which actions make sense for it. Pure, so the wording and the
/// rules can be tested without a widget.
class OutboxStatusView {
  const OutboxStatusView({
    required this.title,
    required this.detail,
    required this.canSendNow,
    required this.canRetry,
  });

  final String title;
  final String detail;

  /// "Send now" helps: the frame is waiting only for time or connection.
  final bool canSendNow;

  /// "Try again" helps: the service refused the frame and the person may have
  /// changed something.
  final bool canRetry;
}

abstract final class OutboxPresentation {
  /// Describes [entry]. [running] is whether a pass is sending right now and
  /// [now] is the current time, used for "next try in …".
  static OutboxStatusView describe(
    OutboxEntry entry, {
    required bool running,
    required DateTime now,
  }) {
    final hold = entry.hold;
    if (hold == null) {
      return OutboxStatusView(
        title: running ? 'Sending…' : 'Waiting to send',
        detail: entry.stage == OutboxStage.mediaUploaded
            ? 'The photo is already uploaded. The frame is next.'
            : 'Saved on this device. It is sent as soon as the app can.',
        canSendNow: !running,
        canRetry: false,
      );
    }
    final next = _nextTry(entry, now);
    return switch (hold) {
      OutboxHold.offline => OutboxStatusView(
          title: 'Waiting for a connection',
          detail: 'Saved on this device. It is sent automatically when you '
              'are back online.$next',
          canSendNow: !running,
          canRetry: false,
        ),
      OutboxHold.serverBusy => OutboxStatusView(
          title: 'Service is busy',
          detail: 'Saved on this device. The app tries again by itself.$next',
          canSendNow: !running,
          canRetry: false,
        ),
      OutboxHold.awaitingReview => OutboxStatusView(
          title: 'Photo is being checked',
          detail: 'A public frame is shown once its photo is approved. The '
              'app checks again by itself.$next',
          canSendNow: !running,
          canRetry: false,
        ),
      OutboxHold.signInRequired => const OutboxStatusView(
          title: 'Sign in to send',
          detail: 'Saved on this device. It is sent after you sign in.',
          canSendNow: false,
          canRetry: false,
        ),
      OutboxHold.rejected => const OutboxStatusView(
          title: 'The service refused this frame',
          detail: 'It stays on this device. Try again, or stop sending it.',
          canSendNow: false,
          canRetry: true,
        ),
      OutboxHold.unsupported => const OutboxStatusView(
          title: 'Cannot be sent yet',
          detail: 'Only frames with a photo are sent for now. Recordings and '
              '3D objects stay on this device.',
          canSendNow: false,
          canRetry: false,
        ),
    };
  }

  /// The local sync status a frame should show for [entry].
  static AnchorSyncStatus syncStatusFor(OutboxEntry entry) {
    final hold = entry.hold;
    if (hold == OutboxHold.rejected || hold == OutboxHold.unsupported) {
      return AnchorSyncStatus.failed;
    }
    return AnchorSyncStatus.queued;
  }

  static String _nextTry(OutboxEntry entry, DateTime now) {
    final at = entry.nextAttemptAt;
    if (at == null) {
      return '';
    }
    final wait = at.difference(now);
    if (wait.inSeconds <= 0) {
      return ' Trying again now.';
    }
    if (wait.inMinutes < 1) {
      return ' Next try in under a minute.';
    }
    if (wait.inHours < 1) {
      return ' Next try in about ${wait.inMinutes} min.';
    }
    return ' Next try in about ${wait.inHours} h.';
  }
}
