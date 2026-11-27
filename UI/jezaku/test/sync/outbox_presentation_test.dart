import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/outbox_presentation.dart';

final _now = DateTime.utc(2026, 11, 27, 9);

OutboxEntry _entry({
  OutboxHold? hold,
  OutboxStage stage = OutboxStage.queued,
  DateTime? next,
}) {
  return OutboxEntry(
    memoryId: 'm1',
    queuedAt: DateTime.utc(2026, 11, 27, 8),
    stage: stage,
    mediaId: stage == OutboxStage.mediaUploaded ? 'media-1' : null,
    hold: hold,
    nextAttemptAt: next,
  );
}

OutboxStatusView _view(OutboxEntry entry, {bool running = false}) =>
    OutboxPresentation.describe(entry, running: running, now: _now);

void main() {
  group('describe', () {
    test('a frame with no problem waits or sends', () {
      expect(_view(_entry()).title, 'Waiting to send');
      expect(_view(_entry()).canSendNow, isTrue);
      expect(_view(_entry(), running: true).title, 'Sending…');
      expect(_view(_entry(), running: true).canSendNow, isFalse);
    });

    test('says the photo is already up when only the frame is left', () {
      expect(
        _view(_entry(stage: OutboxStage.mediaUploaded)).detail,
        contains('already uploaded'),
      );
    });

    test('offline promises an automatic send and a next try', () {
      final view = _view(
        _entry(
          hold: OutboxHold.offline,
          next: _now.add(const Duration(minutes: 4, seconds: 10)),
        ),
      );
      expect(view.title, 'Waiting for a connection');
      expect(view.detail, contains('automatically'));
      expect(view.detail, contains('Next try in about 4 min'));
      expect(view.canSendNow, isTrue);
      expect(view.canRetry, isFalse);
    });

    test('a due or past retry says it is trying now', () {
      final view = _view(
        _entry(
          hold: OutboxHold.serverBusy,
          next: _now.subtract(const Duration(seconds: 3)),
        ),
      );
      expect(view.detail, contains('Trying again now'));
    });

    test('short and long waits read naturally', () {
      expect(
        _view(
          _entry(
            hold: OutboxHold.serverBusy,
            next: _now.add(const Duration(seconds: 20)),
          ),
        ).detail,
        contains('under a minute'),
      );
      expect(
        _view(
          _entry(
            hold: OutboxHold.serverBusy,
            next: _now.add(const Duration(hours: 2, minutes: 1)),
          ),
        ).detail,
        contains('about 2 h'),
      );
    });

    test('awaiting review explains the public rule', () {
      final view = _view(_entry(hold: OutboxHold.awaitingReview));
      expect(view.title, 'Photo is being checked');
      expect(view.detail, contains('public frame'));
    });

    test('sign-in offers nothing to press', () {
      final view = _view(_entry(hold: OutboxHold.signInRequired));
      expect(view.canSendNow, isFalse);
      expect(view.canRetry, isFalse);
      expect(view.detail, contains('after you sign in'));
    });

    test('a refusal offers try again, not send now', () {
      final view = _view(_entry(hold: OutboxHold.rejected));
      expect(view.canRetry, isTrue);
      expect(view.canSendNow, isFalse);
      expect(view.detail, contains('stays on this device'));
    });

    test('unsupported says what stays on the device', () {
      final view = _view(_entry(hold: OutboxHold.unsupported));
      expect(view.detail, contains('stay on this device'));
      expect(view.canRetry, isFalse);
      expect(view.canSendNow, isFalse);
    });
  });

  group('syncStatusFor', () {
    test('only frames that need the person show as failed', () {
      expect(
        OutboxPresentation.syncStatusFor(_entry(hold: OutboxHold.rejected)),
        AnchorSyncStatus.failed,
      );
      expect(
        OutboxPresentation.syncStatusFor(_entry(hold: OutboxHold.unsupported)),
        AnchorSyncStatus.failed,
      );
      for (final hold in [
        null,
        OutboxHold.offline,
        OutboxHold.serverBusy,
        OutboxHold.awaitingReview,
        OutboxHold.signInRequired,
      ]) {
        expect(
          OutboxPresentation.syncStatusFor(_entry(hold: hold)),
          AnchorSyncStatus.queued,
          reason: '$hold',
        );
      }
    });
  });
}
