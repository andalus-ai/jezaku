import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/sync/outbox/outbox_backoff.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/outbox_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 11, 26, 9);

void main() {
  group('OutboxEntry', () {
    test('survives a JSON round trip with every field', () {
      final entry = OutboxEntry(
        memoryId: 'm-1',
        queuedAt: _t0,
        stage: OutboxStage.mediaUploaded,
        mediaId: 'media-9',
        serverMemoryId: 'srv-1',
        attempts: 3,
        hold: OutboxHold.offline,
        nextAttemptAt: _t0.add(const Duration(seconds: 30)),
      );

      final copy = OutboxEntry.fromJson(
        Map<String, Object?>.from(jsonDecode(jsonEncode(entry.toJson())) as Map),
      );

      expect(copy.memoryId, 'm-1');
      expect(copy.queuedAt, _t0);
      expect(copy.stage, OutboxStage.mediaUploaded);
      expect(copy.mediaId, 'media-9');
      expect(copy.serverMemoryId, 'srv-1');
      expect(copy.attempts, 3);
      expect(copy.hold, OutboxHold.offline);
      expect(copy.nextAttemptAt, _t0.add(const Duration(seconds: 30)));
    });

    test('unknown names fall back instead of failing', () {
      final entry = OutboxEntry.fromJson(<String, Object?>{
        'memoryId': 'm-1',
        'queuedAt': _t0.toIso8601String(),
        'stage': 'from-the-future',
        'hold': 'from-the-future',
      });

      expect(entry.stage, OutboxStage.queued);
      expect(entry.hold, isNull);
    });

    test('an entry without an id or a time is refused', () {
      expect(
        () => OutboxEntry.fromJson(<String, Object?>{'queuedAt': 'x'}),
        throwsFormatException,
      );
      expect(
        () => OutboxEntry.fromJson(<String, Object?>{'memoryId': 'm-1'}),
        throwsFormatException,
      );
    });

    test('is due when nothing holds it back', () {
      expect(OutboxEntry(memoryId: 'm', queuedAt: _t0).isDue(_t0), isTrue);
    });

    test('a retrying hold is due only once its delay has passed', () {
      final entry = OutboxEntry(
        memoryId: 'm',
        queuedAt: _t0,
        hold: OutboxHold.offline,
        nextAttemptAt: _t0.add(const Duration(seconds: 15)),
      );

      expect(entry.isDue(_t0), isFalse);
      expect(entry.isDue(_t0.add(const Duration(seconds: 15))), isTrue);
    });

    test('holds that need the user are never due by themselves', () {
      for (final hold in [
        OutboxHold.signInRequired,
        OutboxHold.rejected,
        OutboxHold.unsupported,
      ]) {
        final entry = OutboxEntry(memoryId: 'm', queuedAt: _t0, hold: hold);
        expect(entry.isDue(_t0.add(const Duration(days: 1))), isFalse, reason: '$hold');
      }
    });

    test('a published entry is not due', () {
      final entry = OutboxEntry(
        memoryId: 'm',
        queuedAt: _t0,
        stage: OutboxStage.published,
      );

      expect(entry.isDue(_t0), isFalse);
    });

    test('clearHold removes the hold and the delay together', () {
      final entry = OutboxEntry(
        memoryId: 'm',
        queuedAt: _t0,
        hold: OutboxHold.offline,
        attempts: 2,
        nextAttemptAt: _t0,
      ).copyWith(clearHold: true, attempts: 0);

      expect(entry.hold, isNull);
      expect(entry.nextAttemptAt, isNull);
      expect(entry.attempts, 0);
    });
  });

  group('OutboxBackoff', () {
    Duration? delay(OutboxHold hold, int attempts) =>
        OutboxBackoff.delayFor(hold, attempts);

    test('doubles from 15 seconds up to a 15 minute cap', () {
      expect(delay(OutboxHold.offline, 1), const Duration(seconds: 15));
      expect(delay(OutboxHold.offline, 2), const Duration(seconds: 30));
      expect(delay(OutboxHold.offline, 3), const Duration(seconds: 60));
      expect(delay(OutboxHold.serverBusy, 6), const Duration(seconds: 480));
      expect(delay(OutboxHold.offline, 7), const Duration(minutes: 15));
      expect(delay(OutboxHold.offline, 500), const Duration(minutes: 15));
    });

    test('treats a missing attempt count as the first failure', () {
      expect(delay(OutboxHold.offline, 0), const Duration(seconds: 15));
    });

    test('a photo awaiting review is checked every five minutes', () {
      expect(delay(OutboxHold.awaitingReview, 1), const Duration(minutes: 5));
      expect(delay(OutboxHold.awaitingReview, 9), const Duration(minutes: 5));
    });

    test('holds that need the user have no automatic retry', () {
      for (final hold in [
        OutboxHold.signInRequired,
        OutboxHold.rejected,
        OutboxHold.unsupported,
      ]) {
        expect(delay(hold, 1), isNull, reason: '$hold');
      }
    });
  });

  group('SharedPreferencesOutboxStore', () {
    Future<SharedPreferencesOutboxStore> store(
      Map<String, Object> initial,
    ) async {
      SharedPreferences.setMockInitialValues(initial);
      return SharedPreferencesOutboxStore(
        preferences: await SharedPreferences.getInstance(),
      );
    }

    test('starts empty', () async {
      expect((await store({})).load(), isEmpty);
    });

    test('keeps entries across a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await SharedPreferencesOutboxStore(preferences: prefs).save([
        OutboxEntry(memoryId: 'a', queuedAt: _t0),
        OutboxEntry(memoryId: 'b', queuedAt: _t0, hold: OutboxHold.offline),
      ]);

      final loaded = SharedPreferencesOutboxStore(preferences: prefs).load();

      expect(loaded.map((e) => e.memoryId), ['a', 'b']);
      expect(loaded.last.hold, OutboxHold.offline);
    });

    test('one damaged record does not hide the others', () async {
      final loaded = (await store({
        'jejaku.frame_outbox.v1': jsonEncode([
          {'memoryId': 'a', 'queuedAt': _t0.toIso8601String()},
          'not a map',
          {'queuedAt': 'missing id'},
          {'memoryId': 'b', 'queuedAt': _t0.toIso8601String()},
        ]),
      }))
          .load();

      expect(loaded.map((e) => e.memoryId), ['a', 'b']);
    });

    test('unreadable stored text is treated as empty', () async {
      expect((await store({'jejaku.frame_outbox.v1': '{{'})).load(), isEmpty);
      expect((await store({'jejaku.frame_outbox.v1': '{}'})).load(), isEmpty);
    });
  });
}
