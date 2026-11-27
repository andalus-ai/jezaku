import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/outbox_store.dart';

class _FakePublisher implements FramePublisher {
  final calls = <String>[];
  Object? uploadError;
  Object? reviewError;
  Object? createError;
  MediaReview review = MediaReview.approved;

  int get uploads => calls.where((c) => c == 'upload').length;
  int get creates => calls.where((c) => c.startsWith('create')).length;

  @override
  Future<String> uploadPhoto(FramePhoto photo, {required String ownerId}) async {
    calls.add('upload');
    if (uploadError != null) {
      throw uploadError!;
    }
    return 'media-$uploads';
  }

  @override
  Future<MediaReview> reviewOf(String mediaId) async {
    calls.add('review');
    if (reviewError != null) {
      throw reviewError!;
    }
    return review;
  }

  @override
  Future<String> createFrame(FramePublishJob job, {required String mediaId}) async {
    calls.add('create:${job.memoryId}');
    if (createError != null) {
      throw createError!;
    }
    return 'srv-${job.memoryId}';
  }
}

class _Jobs implements FramePublishJobSource {
  final jobs = <String, FramePublishJob>{};

  @override
  FramePublishJob? jobFor(String memoryId, {required String ownerId}) =>
      jobs[memoryId];
}

FramePublishJob _job(
  String id, {
  String visibility = 'friends',
  bool withPhoto = true,
}) {
  return FramePublishJob(
    memoryId: id,
    ownerId: 'u-1',
    visibility: visibility,
    anchorType: 'hybrid',
    latitude: -6.9,
    longitude: 107.6,
    frameStyle: 'classic',
    capturedAt: DateTime.utc(2026, 11, 26),
    photo: withPhoto
        ? FramePhoto(
            bytes: Uint8List.fromList([1, 2, 3]),
            fileName: '$id.jpg',
            contentType: 'image/jpeg',
          )
        : null,
  );
}

const _network = ApiFailure(ApiFailureReason.network);

ApiFailure _status(int code) => ApiFailure(
      code == 401 || code == 403
          ? ApiFailureReason.notAllowed
          : ApiFailureReason.server,
      statusCode: code,
    );

class _Rig {
  _Rig() {
    processor = FrameOutboxProcessor(
      store: store,
      publisher: publisher,
      jobs: jobs,
      onPublished: (id, serverId) async {
        if (acknowledgeError != null) {
          throw acknowledgeError!;
        }
        published[id] = serverId;
      },
      clock: () => now,
    );
  }

  final store = InMemoryOutboxStore();
  final publisher = _FakePublisher();
  final jobs = _Jobs();
  final published = <String, String>{};
  Object? acknowledgeError;
  DateTime now = DateTime.utc(2026, 11, 26, 9);
  late final FrameOutboxProcessor processor;

  Future<void> add(String id, {String visibility = 'friends', bool photo = true}) {
    jobs.jobs[id] = _job(id, visibility: visibility, withPhoto: photo);
    return processor.enqueue(id);
  }

  OutboxEntry entry(String id) =>
      store.load().firstWhere((e) => e.memoryId == id);

  void wait(Duration duration) => now = now.add(duration);
}

void main() {
  test('a frame goes out: photo, review, frame, then it leaves the outbox', () async {
    final rig = _Rig();
    await rig.add('a');

    final summary = await rig.processor.run(userId: 'u-1');

    expect(rig.publisher.calls, ['upload', 'review', 'create:a']);
    expect(summary.published, 1);
    expect(summary.stillWaiting, 0);
    expect(summary.stoppedBy, isNull);
    expect(rig.published, {'a': 'srv-a'});
    expect(rig.store.load(), isEmpty);
  });

  test('adding the same frame twice keeps one entry', () async {
    final rig = _Rig();
    await rig.add('a');
    await rig.processor.enqueue('a');

    expect(rig.store.load(), hasLength(1));
  });

  group('no connection', () {
    test('holds the frame with a delay and stops, leaving the others alone', () async {
      final rig = _Rig();
      await rig.add('a');
      await rig.add('b');
      rig.publisher.uploadError = _network;

      final summary = await rig.processor.run(userId: 'u-1');

      expect(summary.stoppedBy, OutboxHold.offline);
      expect(summary.published, 0);
      expect(summary.stillWaiting, 2);
      expect(rig.publisher.uploads, 1, reason: 'b is not tried');
      expect(rig.entry('a').hold, OutboxHold.offline);
      expect(rig.entry('a').attempts, 1);
      expect(rig.entry('a').nextAttemptAt,
          rig.now.add(const Duration(seconds: 15)));
      expect(rig.entry('b').attempts, 0);
      expect(rig.entry('b').hold, isNull);
    });

    test('waits for the delay, then sends everything once the network is back', () async {
      final rig = _Rig();
      await rig.add('a');
      await rig.add('b');
      rig.publisher.uploadError = _network;
      await rig.processor.run(userId: 'u-1');
      rig.publisher.uploadError = null;
      rig.publisher.calls.clear();

      final early = await rig.processor.run(userId: 'u-1');
      expect(early.published, 1, reason: 'b was never held back');
      expect(rig.published.keys, ['b']);

      rig.wait(const Duration(seconds: 16));
      final later = await rig.processor.run(userId: 'u-1');

      expect(later.published, 1);
      expect(rig.published.keys, containsAll(['a', 'b']));
      expect(rig.store.load(), isEmpty);
    });

    test('"sync now" ignores the delay', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.publisher.uploadError = _network;
      await rig.processor.run(userId: 'u-1');
      rig.publisher.uploadError = null;

      final summary = await rig.processor.run(userId: 'u-1', force: true);

      expect(summary.published, 1);
    });

    test('the delay grows with each failed attempt', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.publisher.uploadError = _network;
      await rig.processor.run(userId: 'u-1');
      await rig.processor.run(userId: 'u-1', force: true);

      expect(rig.entry('a').attempts, 2);
      expect(rig.entry('a').nextAttemptAt,
          rig.now.add(const Duration(seconds: 30)));
    });

    test('a drop after the photo went up never uploads it twice', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.publisher.createError = _network;
      await rig.processor.run(userId: 'u-1');

      expect(rig.entry('a').stage, OutboxStage.mediaUploaded);
      expect(rig.entry('a').mediaId, 'media-1');

      rig.publisher.createError = null;
      await rig.processor.run(userId: 'u-1', force: true);

      expect(rig.publisher.uploads, 1);
      expect(rig.publisher.creates, 2);
      expect(rig.published, {'a': 'srv-a'});
    });
  });

  group('sign-in', () {
    test('without a user nothing is sent and the frames wait for sign-in', () async {
      final rig = _Rig();
      await rig.add('a');

      final summary = await rig.processor.run(userId: null);

      expect(rig.publisher.calls, isEmpty);
      expect(summary.stoppedBy, OutboxHold.signInRequired);
      expect(summary.stillWaiting, 1);
      expect(rig.entry('a').hold, OutboxHold.signInRequired);
    });

    test('signing in releases them', () async {
      final rig = _Rig();
      await rig.add('a');
      await rig.processor.run(userId: null);

      final summary = await rig.processor.run(userId: 'u-1');

      expect(summary.published, 1);
      expect(rig.store.load(), isEmpty);
    });

    test('a refused session (401) stops the pass and waits for sign-in', () async {
      final rig = _Rig();
      await rig.add('a');
      await rig.add('b');
      rig.publisher.uploadError = _status(401);

      final summary = await rig.processor.run(userId: 'u-1');

      expect(summary.stoppedBy, OutboxHold.signInRequired);
      expect(rig.entry('a').hold, OutboxHold.signInRequired);
      expect(rig.entry('a').nextAttemptAt, isNull);
      expect(rig.publisher.uploads, 1);
    });

    test('not being signed in does not erase why a frame was refused', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.publisher.review = MediaReview.rejected;
      await rig.processor.run(userId: 'u-1');

      await rig.processor.run(userId: null);

      expect(rig.entry('a').hold, OutboxHold.rejected);
    });
  });

  group('public frames and review', () {
    test('wait for approval, check again in five minutes, and let others go', () async {
      final rig = _Rig();
      await rig.add('pub', visibility: 'public');
      await rig.add('friends');
      rig.publisher.review = MediaReview.pending;

      final summary = await rig.processor.run(userId: 'u-1');

      expect(summary.stoppedBy, isNull);
      expect(rig.published.keys, ['friends']);
      expect(rig.entry('pub').hold, OutboxHold.awaitingReview);
      expect(rig.entry('pub').stage, OutboxStage.mediaUploaded);
      expect(rig.entry('pub').nextAttemptAt,
          rig.now.add(const Duration(minutes: 5)));
      expect(rig.publisher.creates, 1);
    });

    test('are created once the photo is approved, without uploading again', () async {
      final rig = _Rig();
      await rig.add('pub', visibility: 'public');
      rig.publisher.review = MediaReview.pending;
      await rig.processor.run(userId: 'u-1');
      rig.publisher.review = MediaReview.approved;
      rig.wait(const Duration(minutes: 6));

      final summary = await rig.processor.run(userId: 'u-1');

      expect(summary.published, 1);
      expect(rig.publisher.uploads, 1);
    });

    test('an approved photo needs no wait', () async {
      final rig = _Rig();
      await rig.add('pub', visibility: 'public');

      expect((await rig.processor.run(userId: 'u-1')).published, 1);
    });

    test('a rejected photo is held for the user and not retried', () async {
      final rig = _Rig();
      await rig.add('pub', visibility: 'public');
      rig.publisher.review = MediaReview.rejected;

      await rig.processor.run(userId: 'u-1');
      rig.publisher.calls.clear();
      await rig.processor.run(userId: 'u-1', force: true);

      expect(rig.entry('pub').hold, OutboxHold.rejected);
      expect(rig.publisher.calls, isEmpty);
    });

    test('"retry" lets a refused frame be sent again', () async {
      final rig = _Rig();
      await rig.add('pub');
      rig.publisher.review = MediaReview.rejected;
      await rig.processor.run(userId: 'u-1');
      rig.publisher.review = MediaReview.approved;

      await rig.processor.retry('pub');
      final summary = await rig.processor.run(userId: 'u-1');

      expect(summary.published, 1);
    });
  });

  group('failures', () {
    test('a refusal (400, 403, 404, 422) is held for the user and the pass goes on', () async {
      for (final code in [400, 403, 404, 422]) {
        final rig = _Rig();
        await rig.add('a');
        await rig.add('b');
        rig.publisher.createError = _status(code);

        final summary = await rig.processor.run(userId: 'u-1');

        expect(rig.entry('a').hold, OutboxHold.rejected, reason: '$code');
        expect(summary.stoppedBy, isNull, reason: '$code');
        expect(rig.publisher.uploads, 2, reason: '$code: b is still tried');
      }
    });

    test('a busy or failing service (408, 429, 500, 503) is retried later and stops the pass', () async {
      for (final code in [408, 429, 500, 503]) {
        final rig = _Rig();
        await rig.add('a');
        await rig.add('b');
        rig.publisher.createError = _status(code);

        final summary = await rig.processor.run(userId: 'u-1');

        expect(rig.entry('a').hold, OutboxHold.serverBusy, reason: '$code');
        expect(rig.entry('a').nextAttemptAt, isNotNull, reason: '$code');
        expect(summary.stoppedBy, OutboxHold.serverBusy, reason: '$code');
        expect(rig.publisher.uploads, 1, reason: '$code');
      }
    });

    test('an answer the app cannot read is retried, never dropped', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.publisher.uploadError = const FormatException('garbled');

      await rig.processor.run(userId: 'u-1');

      expect(rig.entry('a').hold, OutboxHold.serverBusy);
    });

    test('classify maps every failure to a hold', () {
      expect(FrameOutboxProcessor.classify(_network), OutboxHold.offline);
      expect(FrameOutboxProcessor.classify(_status(401)),
          OutboxHold.signInRequired);
      expect(FrameOutboxProcessor.classify(_status(403)), OutboxHold.rejected);
      expect(FrameOutboxProcessor.classify(
              const ApiFailure(ApiFailureReason.server)),
          OutboxHold.serverBusy);
    });
  });

  group('local frames', () {
    test('a frame deleted while waiting is dropped without any call', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.jobs.jobs.remove('a');

      final summary = await rig.processor.run(userId: 'u-1');

      expect(rig.publisher.calls, isEmpty);
      expect(summary.stillWaiting, 0);
    });

    test('a frame without an uploadable photo is held as unsupported', () async {
      final rig = _Rig();
      await rig.add('rec', photo: false);
      await rig.add('b');

      final summary = await rig.processor.run(userId: 'u-1');

      expect(rig.entry('rec').hold, OutboxHold.unsupported);
      expect(summary.stoppedBy, isNull);
      expect(rig.published.keys, ['b']);
      expect(rig.publisher.uploads, 1);
    });

    test('"discard" gives up the upload', () async {
      final rig = _Rig();
      await rig.add('a');

      await rig.processor.discard('a');

      expect(rig.store.load(), isEmpty);
    });
  });

  group('acknowledging', () {
    test('a frame created on the server is never created twice, even if the app could not record it', () async {
      final rig = _Rig();
      await rig.add('a');
      rig.acknowledgeError = StateError('disk full');
      await rig.processor.run(userId: 'u-1');

      expect(rig.entry('a').stage, OutboxStage.published);
      expect(rig.entry('a').serverMemoryId, 'srv-a');

      rig.acknowledgeError = null;
      final summary = await rig.processor.run(userId: 'u-1', force: true);

      expect(rig.publisher.creates, 1);
      expect(summary.published, 1);
      expect(rig.published, {'a': 'srv-a'});
      expect(rig.store.load(), isEmpty);
    });
  });

  test('two calls at once share one pass', () async {
    final rig = _Rig();
    await rig.add('a');

    final first = rig.processor.run(userId: 'u-1');
    final second = rig.processor.run(userId: 'u-1');

    expect(identical(first, second), isTrue);
    await first;
    expect(rig.publisher.uploads, 1);
  });
}
