import 'dart:async';

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
  'hemanthraj/flutter_compass',
  'dev.fluttercommunity.plus/sensors/method',
  'dev.fluttercommunity.plus/sensors/accelerometer',
  'dev.fluttercommunity.plus/sensors/user_accel',
  'dev.fluttercommunity.plus/sensors/gyroscope',
  'dev.fluttercommunity.plus/sensors/magnetometer',
];

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
  });

  await testMain();
}
