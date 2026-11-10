import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARVpsAvailability.fromNative', () {
    test('maps every ARCore VpsAvailability name', () {
      expect(ARVpsAvailability.fromNative('AVAILABLE'),
          ARVpsAvailability.available);
      expect(ARVpsAvailability.fromNative('UNAVAILABLE'),
          ARVpsAvailability.unavailable);
      expect(ARVpsAvailability.fromNative('ERROR_NETWORK_CONNECTION'),
          ARVpsAvailability.errorNetworkConnection);
      expect(ARVpsAvailability.fromNative('ERROR_NOT_AUTHORIZED'),
          ARVpsAvailability.errorNotAuthorized);
      expect(ARVpsAvailability.fromNative('ERROR_RESOURCE_EXHAUSTED'),
          ARVpsAvailability.errorResourceExhausted);
      expect(ARVpsAvailability.fromNative('ERROR_INTERNAL'),
          ARVpsAvailability.errorInternal);
      expect(ARVpsAvailability.fromNative('UNSUPPORTED'),
          ARVpsAvailability.unsupported);
    });

    test('maps null and unknown names to unknown', () {
      expect(ARVpsAvailability.fromNative(null), ARVpsAvailability.unknown);
      expect(ARVpsAvailability.fromNative('SOMETHING_NEW'),
          ARVpsAvailability.unknown);
    });

    test('isError is true only for error values', () {
      expect(ARVpsAvailability.errorNotAuthorized.isError, isTrue);
      expect(ARVpsAvailability.errorNetworkConnection.isError, isTrue);
      expect(ARVpsAvailability.available.isError, isFalse);
      expect(ARVpsAvailability.unavailable.isError, isFalse);
      expect(ARVpsAvailability.unsupported.isError, isFalse);
    });
  });

  group('ARGeospatialStatus', () {
    test('parses a tracking status with accuracy estimates', () {
      final status = ARGeospatialStatus.fromMap(<String, Object?>{
        'enabled': true,
        'tracking': true,
        'earthState': 'ENABLED',
        'pose': <String, Object?>{
          'latitude': -6.2,
          'longitude': 106.8,
          'altitudeMeters': 12.5,
          'headingDegrees': 90.0,
          'horizontalAccuracyMeters': 1.5,
          'verticalAccuracyMeters': 2.0,
          'headingAccuracyDegrees': 0.8,
        },
      });

      expect(status.isEnabled, isTrue);
      expect(status.isTracking, isTrue);
      expect(status.earthState, 'ENABLED');
      expect(status.pose?.latitude, -6.2);
      expect(status.pose?.horizontalAccuracyMeters, 1.5);
      expect(status.pose?.headingAccuracyDegrees, 0.8);
    });

    test('parses a status without a pose', () {
      final status = ARGeospatialStatus.fromMap(<String, Object?>{
        'enabled': true,
        'tracking': false,
        'earthState': 'ERROR_NOT_AUTHORIZED',
        'pose': null,
      });

      expect(status.isTracking, isFalse);
      expect(status.pose, isNull);
      expect(status.isNotAuthorized, isTrue);
    });

    test('accuracy fields stay null when native omits them', () {
      final pose = ARGeospatialPose.fromMap(<String, Object?>{
        'latitude': 1.0,
        'longitude': 2.0,
      });

      expect(pose.altitudeMeters, 0);
      expect(pose.horizontalAccuracyMeters, isNull);
      expect(pose.headingAccuracyDegrees, isNull);
    });

    test('round-trips through toMap', () {
      const status = ARGeospatialStatus(
        isEnabled: true,
        isTracking: true,
        earthState: 'ENABLED',
        pose: ARGeospatialPose(
          latitude: 1,
          longitude: 2,
          altitudeMeters: 3,
          headingDegrees: 4,
          horizontalAccuracyMeters: 5,
          verticalAccuracyMeters: 6,
          headingAccuracyDegrees: 7,
        ),
      );

      expect(ARGeospatialStatus.fromMap(status.toMap()), status);
    });

    test('unsupported status is disabled and not tracking', () {
      const status = ARGeospatialStatus.unsupported();

      expect(status.isEnabled, isFalse);
      expect(status.isTracking, isFalse);
      expect(status.pose, isNull);
    });
  });

  group('ARController geospatial status', () {
    late ArEnginePlatform originalPlatform;
    late ArEngineTestHarness harness;

    setUp(() {
      originalPlatform = ArEnginePlatform.instance;
      harness = ArEngineTestHarness.install();
    });

    tearDown(() {
      harness.restore();
      ArEnginePlatform.instance = originalPlatform;
    });

    test('checkVpsAvailability forwards coordinates to the platform',
        () async {
      harness.platform.vpsAvailability = ARVpsAvailability.unavailable;
      final controller = await harness.createController();

      final result = await controller.checkVpsAvailability(
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(result, ARVpsAvailability.unavailable);
      expect(harness.platform.vpsAvailabilityRequests, <List<double>>[
        <double>[-6.2, 106.8],
      ]);
    });

    test('checkVpsAvailability rejects out-of-range coordinates', () async {
      final controller = await harness.createController();

      expect(
        () => controller.checkVpsAvailability(latitude: 91, longitude: 0),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => controller.checkVpsAvailability(latitude: 0, longitude: 181),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => controller.checkVpsAvailability(
          latitude: double.nan,
          longitude: 0,
        ),
        throwsA(isA<RangeError>()),
      );
      expect(harness.platform.vpsAvailabilityRequests, isEmpty);
    });

    test('getGeospatialStatus returns the platform status', () async {
      harness.platform.geospatialStatus = const ARGeospatialStatus(
        isEnabled: true,
        isTracking: true,
        earthState: 'ENABLED',
        pose: ARGeospatialPose(
          latitude: 1,
          longitude: 2,
          altitudeMeters: 3,
          headingDegrees: 4,
          horizontalAccuracyMeters: 1.2,
          headingAccuracyDegrees: 0.5,
        ),
      );
      final controller = await harness.createController();

      final status = await controller.getGeospatialStatus();

      expect(status.isTracking, isTrue);
      expect(status.pose?.horizontalAccuracyMeters, 1.2);
    });

    test('platform errors propagate', () async {
      harness.platform.checkVpsAvailabilityError =
          PlatformException(code: 'VPS_CHECK_FAILED');
      final controller = await harness.createController();

      expect(
        () => controller.checkVpsAvailability(latitude: 0, longitude: 0),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('ArEngineMethodChannel without a native plugin', () {
    test('geospatial queries report unsupported', () async {
      // No handler is registered for the channel in unit tests, so the call
      // raises MissingPluginException, which must map to "unsupported".
      final channel = ArEngineMethodChannel();

      expect(
        await channel.checkVpsAvailability(latitude: 0, longitude: 0),
        ARVpsAvailability.unsupported,
      );
      expect(
        await channel.getGeospatialStatus(),
        const ARGeospatialStatus.unsupported(),
      );
    });
  });
}
