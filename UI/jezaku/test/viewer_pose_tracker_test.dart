import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/app/utils/bounded_timers.dart';
import 'package:jejaku/features/ar_viewer/services/viewer_pose_tracker.dart';

class _FakeLocation implements ViewerLocationGateway {
  _FakeLocation({
    this.enabled = true,
    this.initial = LocationPermission.whileInUse,
    this.afterRequest = LocationPermission.whileInUse,
  });

  bool enabled;
  LocationPermission initial;
  LocationPermission afterRequest;
  int requests = 0;
  final positions = StreamController<Position>.broadcast();

  @override
  Future<bool> isServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => initial;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return afterRequest;
  }

  @override
  Stream<Position> positionStream() => positions.stream;
}

Position _position(double latitude) {
  return Position(
    latitude: latitude,
    longitude: 107.6,
    timestamp: DateTime.utc(2026, 6, 2),
    accuracy: 5,
    altitude: 700,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}

void main() {
  late BoundedTimers timers;
  late List<double> headings;
  late List<Position> positions;

  setUp(() {
    timers = BoundedTimers();
    headings = [];
    positions = [];
  });

  tearDown(() => timers.cancelAll());

  ViewerPoseTracker build(
    _FakeLocation location, {
    StreamController<double?>? compass,
  }) {
    return ViewerPoseTracker(
      onHeading: headings.add,
      onPosition: positions.add,
      timers: timers,
      location: location,
      compass: () => compass?.stream,
    );
  }

  group('compass', () {
    test('forwards normalised headings and ignores null or non-finite ones', () async {
      final compass = StreamController<double?>();
      final tracker = build(_FakeLocation(), compass: compass);

      tracker.startCompass();
      compass
        ..add(-10)
        ..add(null)
        ..add(double.nan)
        ..add(725);
      await Future<void>.delayed(Duration.zero);

      expect(headings, [350, 5]);
      expect(tracker.isTrackingCompass, isTrue);
      tracker.stop();
      await compass.close();
    });

    test('a device without a compass simply tracks nothing', () {
      final tracker = build(_FakeLocation());
      tracker.startCompass();
      expect(tracker.isTrackingCompass, isFalse);
    });
  });

  group('position', () {
    test('streams positions once enabled and permitted', () async {
      final location = _FakeLocation();
      final tracker = build(location);

      await tracker.startPosition(isActive: () => true);
      location.positions.add(_position(-6.9));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.isTrackingPosition, isTrue);
      expect(positions.single.latitude, -6.9);
      tracker.stop();
    });

    test('does nothing when location services are off', () async {
      final tracker = build(_FakeLocation(enabled: false));
      await tracker.startPosition(isActive: () => true);
      expect(tracker.isTrackingPosition, isFalse);
    });

    test('asks for permission when denied, and stops if still refused', () async {
      final location = _FakeLocation(
        initial: LocationPermission.denied,
        afterRequest: LocationPermission.deniedForever,
      );
      final tracker = build(location);

      await tracker.startPosition(isActive: () => true);

      expect(location.requests, 1);
      expect(tracker.isTrackingPosition, isFalse);
    });

    test('proceeds when the permission request is granted', () async {
      final location = _FakeLocation(
        initial: LocationPermission.denied,
        afterRequest: LocationPermission.always,
      );
      final tracker = build(location);

      await tracker.startPosition(isActive: () => true);

      expect(tracker.isTrackingPosition, isTrue);
      tracker.stop();
    });

    test('an owner that went away mid-start is never subscribed', () async {
      var active = true;
      final location = _FakeLocation();
      final tracker = build(location);

      final starting = tracker.startPosition(isActive: () => active);
      active = false;
      await starting;

      expect(tracker.isTrackingPosition, isFalse);
    });

    test('stop cancels both streams and later readings are dropped', () async {
      final compass = StreamController<double?>.broadcast();
      final location = _FakeLocation();
      final tracker = build(location, compass: compass);
      tracker.startCompass();
      await tracker.startPosition(isActive: () => true);

      tracker.stop();
      compass.add(10);
      location.positions.add(_position(-6.9));
      await Future<void>.delayed(Duration.zero);

      expect(tracker.isTrackingCompass, isFalse);
      expect(tracker.isTrackingPosition, isFalse);
      expect(headings, isEmpty);
      expect(positions, isEmpty);
    });
  });
}
