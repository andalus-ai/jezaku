import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plugin channels the app touches directly. Without a handler, a call made
/// under `testWidgets` never completes (the platform reply is not delivered
/// through fake async), so flows such as capture stall until their timeouts.
/// These stubs answer immediately with "no hardware" values.
const _stubbedMethodChannels = <String>[
  'flutter.baseflow.com/geolocator',
  'flutter.baseflow.com/geolocator_updates',
  'flutter.baseflow.com/geolocator_service_updates',
  'flutter.baseflow.com/permissions/methods',
  'dev.fluttercommunity.plus/sensors/method',
  'dev.fluttercommunity.plus/sensors/user_accel',
  'dev.fluttercommunity.plus/sensors/gyroscope',
  'dev.fluttercommunity.plus/sensors/magnetometer',
];

/// Sensor readings that match the capture session's default preview pose
/// (heading 245 deg, pitch -2 deg, roll 0.4 deg), so a sensor refresh during a
/// test leaves the snapshot unchanged instead of waiting on a missing sensor.
const _compassChannel = EventChannel('hemanthraj/flutter_compass');
const _accelerometerChannel = EventChannel(
  'dev.fluttercommunity.plus/sensors/accelerometer',
);

List<double> _accelerometerForDefaultPose() {
  const gravity = 9.80665;
  final pitch = -2 * math.pi / 180;
  final roll = 0.4 * math.pi / 180;
  final planar = gravity;
  return <double>[
    -math.tan(pitch) * planar,
    planar * math.sin(roll),
    planar * math.cos(roll),
  ];
}

Future<Object?> _stubHandler(MethodCall call) async {
  switch (call.method) {
    case 'isLocationServiceEnabled':
    case 'openAppSettings':
    case 'openLocationSettings':
    case 'shouldShowRequestPermissionRationale':
      return false;
    case 'checkPermission':
    case 'requestPermission':
    case 'checkPermissionStatus':
    case 'checkServiceStatus':
      return 0;
    case 'requestPermissions':
      return <int, int>{};
    default:
      return null;
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in _stubbedMethodChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), _stubHandler);
    }
    messenger.setMockStreamHandler(
      _compassChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) =>
            events.success(<double>[245, 245, 5]),
      ),
    );
    messenger.setMockStreamHandler(
      _accelerometerChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) =>
            events.success(_accelerometerForDefaultPose()),
      ),
    );
  });

  await testMain();
}
