import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/native_scene_sync_loop.dart';
import 'package:jejaku/features/ar_viewer/services/post_frame_coalescer.dart';

void main() {
  group('PostFrameCoalescer', () {
    test('collapses requests made before the frame into one run', () {
      final queued = <VoidCallback>[];
      var runs = 0;
      final coalescer = PostFrameCoalescer(
        action: () => runs++,
        postFrame: queued.add,
      );

      coalescer
        ..schedule()
        ..schedule()
        ..schedule();

      expect(queued, hasLength(1));
      expect(coalescer.isScheduled, isTrue);
      queued.single();
      expect(runs, 1);
      expect(coalescer.isScheduled, isFalse);
    });

    test('can be scheduled again once the frame has run', () {
      final queued = <VoidCallback>[];
      final coalescer = PostFrameCoalescer(
        action: () {},
        postFrame: queued.add,
      );

      coalescer.schedule();
      queued.removeLast()();
      coalescer.schedule();

      expect(queued, hasLength(1));
    });

    test('the action may schedule the next run itself', () {
      final queued = <VoidCallback>[];
      late final PostFrameCoalescer coalescer;
      var runs = 0;
      coalescer = PostFrameCoalescer(
        action: () {
          if (++runs == 1) {
            coalescer.schedule();
          }
        },
        postFrame: queued.add,
      );

      coalescer.schedule();
      queued.removeLast()();

      expect(queued, hasLength(1));
    });
  });

  group('NativeSceneSyncLoop', () {
    late bool active;
    late bool allowed;
    late bool scene;
    late String fingerprint;
    late List<String> synced;
    late List<Object> failures;
    late List<VoidCallback> frames;
    late Completer<bool>? gate;
    late bool Function() abortWhen;
    late NativeSceneSyncLoop loop;

    setUp(() {
      active = true;
      allowed = true;
      scene = true;
      fingerprint = 'a';
      synced = <String>[];
      failures = <Object>[];
      frames = <VoidCallback>[];
      gate = null;
      abortWhen = () => false;
      loop = NativeSceneSyncLoop(
        isActive: () => active,
        canSync: () => allowed,
        hasScene: () => scene,
        postFrame: frames.add,
        onFailure: failures.add,
        prepare: () {
          if (!scene) {
            return null;
          }
          final fp = fingerprint;
          return NativeSceneSyncAttempt(
            fingerprint: fp,
            run: () async {
              final pending = gate;
              if (pending != null) {
                await pending.future;
              }
              if (fp == 'boom') {
                throw StateError('native failure');
              }
              if (abortWhen()) {
                return false;
              }
              synced.add(fp);
              return true;
            },
          );
        },
      );
    });

    Future<void> flushFrames() async {
      while (frames.isNotEmpty) {
        frames.removeAt(0)();
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('syncs once and skips unchanged inputs', () async {
      await loop.run();
      await loop.run();

      expect(synced, <String>['a']);
      expect(loop.isCurrent('a'), isTrue);
    });

    test('invalidate forces the same inputs to sync again', () async {
      await loop.run();
      loop.invalidate();
      await loop.run();

      expect(synced, <String>['a', 'a']);
    });

    test('does nothing while placement is not allowed', () async {
      allowed = false;

      await loop.run();

      expect(synced, isEmpty);
      expect(loop.isSyncing, isFalse);
    });

    test('does nothing without a scene', () async {
      scene = false;

      await loop.run();

      expect(synced, isEmpty);
    });

    test('schedule syncs after the frame and ignores an inactive owner',
        () async {
      loop.schedule();
      loop.schedule();
      expect(frames, hasLength(1));
      await flushFrames();
      expect(synced, <String>['a']);

      active = false;
      fingerprint = 'b';
      loop.schedule();
      await flushFrames();
      expect(synced, <String>['a']);
    });

    test('does not run two syncs at once', () async {
      gate = Completer<bool>();
      final first = loop.run();
      await Future<void>.delayed(Duration.zero);
      expect(loop.isSyncing, isTrue);

      await loop.run();
      gate!.complete(true);
      await first;

      expect(synced, <String>['a']);
    });

    test('keeps syncing until the inputs stop changing', () async {
      var step = 0;
      final steps = <String>['a', 'b', 'b'];
      final loop = NativeSceneSyncLoop(
        isActive: () => true,
        canSync: () => true,
        hasScene: () => true,
        postFrame: frames.add,
        onFailure: failures.add,
        prepare: () {
          final fp = steps[step < steps.length ? step++ : steps.length - 1];
          return NativeSceneSyncAttempt(
            fingerprint: fp,
            run: () async {
              synced.add(fp);
              return true;
            },
          );
        },
      );

      await loop.run();

      expect(synced, <String>['a', 'b']);
      expect(loop.lastFingerprint, 'b');
    });

    test('an abandoned attempt does not record its fingerprint', () async {
      abortWhen = () => true;

      await loop.run();

      expect(synced, isEmpty);
      expect(loop.lastFingerprint, isNull);
      expect(failures, isEmpty);
    });

    test('a failure is reported and not retried for the same inputs',
        () async {
      fingerprint = 'boom';

      await loop.run();
      await loop.run();

      expect(failures, hasLength(1));
      expect(failures.single, isA<StateError>());
      expect(loop.isCurrent('boom'), isTrue);

      fingerprint = 'ok';
      await loop.run();
      expect(synced, <String>['ok']);
    });

    test('refresh without a scene reports false and clears the queue', () {
      scene = false;

      expect(loop.refresh(), isFalse);
      expect(loop.isRefreshQueued, isFalse);
      expect(frames, isEmpty);
    });

    test('refresh schedules a sync when idle', () async {
      await loop.run();

      expect(loop.refresh(), isTrue);
      expect(loop.lastFingerprint, isNull);
      await flushFrames();

      expect(synced, <String>['a', 'a']);
    });

    test('refresh during a sync queues one more run after it ends', () async {
      gate = Completer<bool>();
      final running = loop.run();
      await Future<void>.delayed(Duration.zero);

      expect(loop.refresh(), isTrue);
      expect(loop.isRefreshQueued, isTrue);
      expect(frames, isEmpty);

      gate!.complete(true);
      await running;

      expect(loop.isRefreshQueued, isFalse);
      expect(frames, hasLength(1));
    });

    test('dispose drops a queued refresh', () async {
      gate = Completer<bool>();
      final running = loop.run();
      await Future<void>.delayed(Duration.zero);
      loop.refresh();

      loop.dispose();
      gate!.complete(true);
      await running;

      expect(frames, isEmpty);
    });
  });
}
