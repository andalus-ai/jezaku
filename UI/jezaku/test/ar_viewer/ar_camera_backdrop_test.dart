import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_runtime_permission_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_camera_backdrop.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_projection_backdrop.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

class _Calls {
  final retryPermissions = <int>[];
  final openSettings = <int>[];
  final refreshScene = <int>[];
}

Widget _host(
  Future<ARRuntimePermissions> permissions,
  _Calls calls, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: ARCameraBackdrop(
          permissions: permissions,
          sessionGeneration: 0,
          controller: null,
          onRetryPermissions: () => calls.retryPermissions.add(1),
          onOpenPermissionSettings: () => calls.openSettings.add(1),
          onRefreshScene: () => calls.refreshScene.add(1),
          onViewCreated: (_) {},
          onSessionConfigResolved: (_) {},
          onSessionHealthChanged: (_) {},
          onSessionHealthAssessmentChanged: (_) {},
          onSessionDiagnosticsReportChanged: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('says the camera is being requested while permission is pending',
      (tester) async {
    final pending = Completer<ARRuntimePermissions>();

    await tester.pumpWidget(_host(pending.future, _Calls()));

    expect(find.text('Requesting camera'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a denied camera explains itself and lets the person grant it',
      (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _host(Future.value(const ARRuntimePermissions.denied()), calls),
    );
    await tester.pump();

    expect(find.text('Camera permission needed'), findsOneWidget);
    expect(
      find.text('Allow camera access so ARCore can start the live preview.'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsNothing);

    await tester.tap(find.text('Grant access'));

    expect(calls.retryPermissions, hasLength(1));
    expect(calls.openSettings, isEmpty);
  });

  testWidgets('a camera that is blocked for good sends the person to settings',
      (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _host(
        Future.value(
          const ARRuntimePermissions(
            cameraStatus: PermissionStatus.permanentlyDenied,
            locationStatus: PermissionStatus.granted,
          ),
        ),
        calls,
      ),
    );
    await tester.pump();

    expect(find.text('Grant access'), findsNothing);

    await tester.tap(find.text('Open settings'));

    expect(calls.openSettings, hasLength(1));
    expect(calls.retryPermissions, isEmpty);
  });

  testWidgets('with the camera allowed it waits for the session to be planned',
      (tester) async {
    final planning = Completer<ARSessionConfig>();
    await tester.pumpWidget(
      _host(
        Future.value(const ARRuntimePermissions.granted()),
        _Calls(),
        overrides: [
          arViewerSessionConfigProvider.overrideWith((ref) => planning.future),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Preparing AR session'), findsOneWidget);
  });

  testWidgets('a session that cannot be planned says so and can be retried',
      (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      _host(
        Future.value(const ARRuntimePermissions.granted()),
        _Calls(),
        overrides: [
          arViewerSessionConfigProvider.overrideWith((ref) async {
            builds++;
            throw StateError('no plan');
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('AR session unavailable'), findsOneWidget);
    expect(find.textContaining('no plan'), findsOneWidget);
    final first = builds;

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(builds, greaterThan(first));
  });

  group('ARProjectionBackdrop', () {
    testWidgets('shows only the status line when there is nothing to do',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ARProjectionBackdrop(statusLabel: 'Starting AR camera'),
        ),
      );

      expect(find.text('Starting AR camera'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('draws the message and the button together, and only then',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ARProjectionBackdrop(
            statusLabel: 'Unavailable',
            message: 'Something went wrong',
            actionLabel: 'Retry',
            onAction: () => pressed++,
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(pressed, 1);

      await tester.pumpWidget(
        const MaterialApp(
          home: ARProjectionBackdrop(
            statusLabel: 'Unavailable',
            actionLabel: 'Retry',
          ),
        ),
      );
      expect(find.text('Retry'), findsNothing,
          reason: 'a button without an action would do nothing');
    });
  });
}
