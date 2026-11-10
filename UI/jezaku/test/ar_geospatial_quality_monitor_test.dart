import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_geospatial_quality_monitor.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

ARGeospatialStatus _status({
  required bool tracking,
  double horizontal = 1.5,
  double heading = 2,
  String earthState = 'ENABLED',
}) {
  return ARGeospatialStatus(
    isEnabled: true,
    isTracking: tracking,
    earthState: earthState,
    pose: tracking
        ? ARGeospatialPose(
            latitude: -6.9175,
            longitude: 107.6191,
            altitudeMeters: 714,
            headingDegrees: 90,
            horizontalAccuracyMeters: horizontal,
            verticalAccuracyMeters: 2,
            headingAccuracyDegrees: heading,
          )
        : null,
  );
}

void main() {
  test('starts approximate and becomes precise once accuracy is good',
      () async {
    final statuses = <ARGeospatialStatus>[
      _status(tracking: false),
      _status(tracking: true, horizontal: 8),
      _status(tracking: true),
    ];
    var index = 0;
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => statuses[index++],
    );
    addTearDown(monitor.dispose);

    expect(monitor.assessment.value.isPrecise, isFalse);

    await monitor.poll();
    expect(monitor.assessment.value.reason, JejakuPlacementReason.localizing);

    await monitor.poll();
    expect(
      monitor.assessment.value.reason,
      JejakuPlacementReason.horizontalAccuracyTooLow,
    );
    expect(monitor.hasBeenPrecise, isFalse);

    await monitor.poll();
    expect(monitor.assessment.value.isPrecise, isTrue);
    expect(monitor.hasBeenPrecise, isTrue);
  });

  test('onFirstPrecise fires once even if precision comes and goes', () async {
    final statuses = <ARGeospatialStatus>[
      _status(tracking: true),
      _status(tracking: true, horizontal: 9),
      _status(tracking: true),
    ];
    var index = 0;
    var calls = 0;
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => statuses[index++],
      onFirstPrecise: () => calls++,
    );
    addTearDown(monitor.dispose);

    await monitor.poll();
    await monitor.poll();
    await monitor.poll();

    expect(calls, 1);
    // The label still follows the current accuracy.
    expect(monitor.assessment.value.isPrecise, isTrue);
  });

  test('the label drops back to approximate when accuracy degrades',
      () async {
    final statuses = <ARGeospatialStatus>[
      _status(tracking: true),
      _status(tracking: true, horizontal: 9),
    ];
    var index = 0;
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => statuses[index++],
    );
    addTearDown(monitor.dispose);

    await monitor.poll();
    await monitor.poll();

    expect(monitor.assessment.value.isPrecise, isFalse);
    expect(monitor.hasBeenPrecise, isTrue);
  });

  test('a failing status read is treated as approximate, not an error',
      () async {
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => throw StateError('native failure'),
    );
    addTearDown(monitor.dispose);

    await monitor.poll();

    expect(monitor.assessment.value.isPrecise, isFalse);
    expect(
      monitor.assessment.value.reason,
      JejakuPlacementReason.geospatialUnavailable,
    );
  });

  test('a throwing onFirstPrecise does not break polling', () async {
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => _status(tracking: true),
      onFirstPrecise: () => throw StateError('sync failed'),
    );
    addTearDown(monitor.dispose);

    await monitor.poll();
    await monitor.poll();

    expect(monitor.assessment.value.isPrecise, isTrue);
  });

  test('VPS authorization errors are surfaced', () async {
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => _status(tracking: true),
    );
    addTearDown(monitor.dispose);
    monitor.setVpsAvailability(ARVpsAvailability.errorNotAuthorized);

    await monitor.poll();

    expect(monitor.assessment.value.reason, JejakuPlacementReason.notAuthorized);
    expect(monitor.hasBeenPrecise, isFalse);
  });

  test('overlapping polls are ignored while a read is in flight', () async {
    final gate = Completer<ARGeospatialStatus>();
    var reads = 0;
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () {
        reads++;
        return gate.future;
      },
    );
    addTearDown(monitor.dispose);

    final first = monitor.poll();
    await monitor.poll();
    expect(reads, 1);

    gate.complete(_status(tracking: true));
    await first;
    expect(monitor.assessment.value.isPrecise, isTrue);
  });

  test('assessment only notifies on change', () async {
    final monitor = ARGeospatialQualityMonitor(
      readStatus: () async => _status(tracking: true),
    );
    addTearDown(monitor.dispose);
    var notifications = 0;
    monitor.assessment.addListener(() => notifications++);

    await monitor.poll();
    await monitor.poll();
    await monitor.poll();

    expect(notifications, 1);
  });

  test('start polls immediately then on the interval; dispose stops it',
      () async {
    var reads = 0;
    final monitor = ARGeospatialQualityMonitor(
      interval: const Duration(milliseconds: 20),
      readStatus: () async {
        reads++;
        return _status(tracking: false);
      },
    );

    monitor.start();
    expect(monitor.isRunning, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(reads, greaterThanOrEqualTo(2));

    monitor.dispose();
    final readsAtDispose = reads;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(monitor.isRunning, isFalse);
    expect(reads, readsAtDispose);
  });
}
