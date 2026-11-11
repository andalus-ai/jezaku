// TEMPORARY diagnostic for CI; remove once the publish-flow failures are fixed.
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  testWidgets('DIAG sensors', (tester) async {
    debugPrint('DIAG compass events null? ${FlutterCompass.events == null}');
    var compassDone = false;
    FlutterCompass.events?.first.then((e) {
      compassDone = true;
      debugPrint('DIAG compass event ${e.heading}');
    }, onError: (Object e) => debugPrint('DIAG compass error $e'));
    var accDone = false;
    accelerometerEventStream().first.then((e) {
      accDone = true;
      debugPrint('DIAG acc event ${e.x} ${e.y} ${e.z}');
    }, onError: (Object e) => debugPrint('DIAG acc error $e'));
    var geoDone = false;
    Geolocator.isLocationServiceEnabled().then((v) {
      geoDone = true;
      debugPrint('DIAG geo enabled=$v');
    }, onError: (Object e) {
      geoDone = true;
      debugPrint('DIAG geo error $e');
    });
    await tester.pump();
    debugPrint('DIAG after pump0 compass=$compassDone acc=$accDone geo=$geoDone');
    await tester.pump(const Duration(seconds: 1));
    debugPrint('DIAG after pump1s compass=$compassDone acc=$accDone geo=$geoDone');
  });

  testWidgets('DIAG refresh', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(captureSessionProvider.notifier);
    var done = false;
    notifier.refreshPreviewFromDeviceSensors().then((_) => done = true);
    await tester.pump();
    debugPrint('DIAG refresh done after pump0: $done');
    await tester.pump(const Duration(seconds: 3));
    debugPrint('DIAG refresh done after 3s: $done');
    await tester.pump(const Duration(seconds: 10));
    debugPrint('DIAG refresh done after 13s: $done');
  });
}
