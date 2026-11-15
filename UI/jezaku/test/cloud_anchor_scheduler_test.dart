import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/cloud_anchor_scheduler.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

AnchorMemory _memory(String id, {DateTime? cloudExpiresAt}) {
  return AnchorMemory(
    id: id,
    title: id,
    caption: 'Pinned in AR.',
    distanceLabel: '12 m',
    capturedAgo: 'Today',
    locationLabel: 'Bandung',
    latitude: -6.9174,
    longitude: 107.6192,
    reactions: 0,
    captureMetadata: AnchorCaptureMetadata(
      altitudeMeters: 714,
      headingDegrees: 45,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: 3,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass',
      localAnchorId: cloudExpiresAt == null ? null : 'anchor_$id',
      cloudAnchorId: cloudExpiresAt == null ? null : 'cloud_$id',
      cloudAnchorExpiresAt: cloudExpiresAt,
    ),
  );
}

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) {
      return;
    }
    _active = false;
    _callback();
  }
}

class _Timers {
  final created = <_FakeTimer>[];

  Timer create(Duration delay, void Function() callback) {
    final timer = _FakeTimer(delay, callback);
    created.add(timer);
    return timer;
  }

  _FakeTimer get last => created.last;
}

void main() {
  final now = DateTime.utc(2026, 6, 1, 12);
  late _Timers timers;
  late int retries;
  late int maintenances;

  CloudAnchorScheduler build() {
    return CloudAnchorScheduler(
      onRetryDue: () => retries++,
      onMaintenanceDue: () => maintenances++,
      now: () => now,
      timerFactory: timers.create,
    );
  }

  setUp(() {
    timers = _Timers();
    retries = 0;
    maintenances = 0;
  });

  group('retry', () {
    test('schedules a delayed retry and fires the callback once', () {
      final scheduler = build();

      final decision = scheduler.scheduleRetry({'a'});

      expect(decision?.shouldRetry, isTrue);
      expect(decision?.delay, const Duration(seconds: 10));
      expect(scheduler.retryState.attempt, 1);
      expect(scheduler.hasRetryScheduled, isTrue);

      timers.last.fire();
      expect(retries, 1);
      expect(scheduler.hasRetryScheduled, isFalse);
    });

    test('the same failures do not reschedule while a retry is pending', () {
      final scheduler = build();
      scheduler.scheduleRetry({'a', 'b'});

      expect(scheduler.scheduleRetry({'b', 'a'}), isNull);
      expect(timers.created, hasLength(1));
    });

    test('repeated failure after a retry backs off', () {
      final scheduler = build();
      scheduler.scheduleRetry({'a'});
      timers.last.fire();

      final second = scheduler.scheduleRetry({'a'});

      expect(second?.delay, const Duration(seconds: 20));
      expect(scheduler.retryState.attempt, 2);
    });

    test('different failures restart the backoff', () {
      final scheduler = build();
      scheduler.scheduleRetry({'a'});
      timers.last.fire();
      scheduler.scheduleRetry({'a'});
      timers.last.fire();

      final other = scheduler.scheduleRetry({'b'});

      expect(other?.delay, const Duration(seconds: 10));
      expect(scheduler.retryState.attempt, 1);
    });

    test('no failures cancels a pending retry and resets state', () {
      final scheduler = build();
      scheduler.scheduleRetry({'a'});
      final pending = timers.last;

      expect(scheduler.scheduleRetry(<String>{}), isNull);

      expect(pending.isActive, isFalse);
      expect(scheduler.hasRetryScheduled, isFalse);
      expect(scheduler.retryState.attempt, 0);
      pending.fire();
      expect(retries, 0);
    });
  });

  group('maintenance', () {
    test('anchors already due trigger the callback immediately', () {
      final scheduler = build();

      scheduler.scheduleMaintenance([
        _memory('old', cloudExpiresAt: now.add(const Duration(days: 1))),
      ]);

      expect(maintenances, 1);
      expect(timers.created, isEmpty);
      expect(scheduler.hasMaintenanceScheduled, isFalse);
    });

    test('sets a timer for the earliest renewal and fires it once', () {
      final scheduler = build();

      scheduler.scheduleMaintenance([
        _memory('later', cloudExpiresAt: now.add(const Duration(days: 20))),
        _memory('sooner', cloudExpiresAt: now.add(const Duration(days: 10))),
      ]);

      // Renewal is 3 days before expiry, so 7 days from now.
      expect(timers.last.delay, const Duration(days: 7));
      expect(scheduler.maintenanceCheckAt, now.add(const Duration(days: 7)));
      expect(maintenances, 0);

      timers.last.fire();
      expect(maintenances, 1);
      expect(scheduler.maintenanceCheckAt, isNull);
    });

    test('an unchanged plan keeps the existing timer', () {
      final scheduler = build();
      final memories = [
        _memory('a', cloudExpiresAt: now.add(const Duration(days: 10))),
      ];

      scheduler.scheduleMaintenance(memories);
      scheduler.scheduleMaintenance(memories);

      expect(timers.created, hasLength(1));
    });

    test('memories without expiring anchors cancel any pending check', () {
      final scheduler = build();
      scheduler.scheduleMaintenance([
        _memory('a', cloudExpiresAt: now.add(const Duration(days: 10))),
      ]);
      final pending = timers.last;

      scheduler.scheduleMaintenance([_memory('plain')]);

      expect(pending.isActive, isFalse);
      expect(scheduler.maintenanceCheckAt, isNull);
    });
  });

  test('cancelAll stops both timers and clears backoff', () {
    final scheduler = build();
    scheduler.scheduleRetry({'a'});
    scheduler.scheduleMaintenance([
      _memory('a', cloudExpiresAt: now.add(const Duration(days: 10))),
    ]);

    scheduler.cancelAll();

    expect(timers.created.every((timer) => !timer.isActive), isTrue);
    expect(scheduler.retryState.attempt, 0);
    expect(scheduler.maintenanceCheckAt, isNull);
  });
}
