import 'dart:async';

import 'package:ar_engine/ar_engine.dart' hide ARWidget;
import 'package:ar_engine/src/ar_widget.dart' as ar_widget;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_ar_engine_platform.dart';

void main() {
  late ArEnginePlatform originalPlatform;
  late ArEngineTestHarness? arHarness;

  setUp(() {
    originalPlatform = ArEnginePlatform.instance;
    arHarness = null;
  });

  tearDown(() {
    arHarness?.restore();
    ArEnginePlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  TestArEnginePlatform installPlatform([TestArEnginePlatform? platform]) {
    arHarness?.restore();
    arHarness = ArEngineTestHarness.install(platform: platform);
    return arHarness!.platform;
  }

  group('shouldLoadArEngineDesktopTexture', () {
    test('loads texture IDs only for Windows and Linux desktop backends', () {
      expect(
        ar_widget.shouldLoadArEngineDesktopTexture(
          isWeb: false,
          targetPlatform: TargetPlatform.windows,
        ),
        isTrue,
      );
      expect(
        ar_widget.shouldLoadArEngineDesktopTexture(
          isWeb: false,
          targetPlatform: TargetPlatform.linux,
        ),
        isTrue,
      );
      expect(
        ar_widget.shouldLoadArEngineDesktopTexture(
          isWeb: false,
          targetPlatform: TargetPlatform.macOS,
        ),
        isFalse,
      );
      expect(
        ar_widget.shouldLoadArEngineDesktopTexture(
          isWeb: true,
          targetPlatform: TargetPlatform.windows,
        ),
        isFalse,
      );
    });
  });

  group('resolveArEnginePlatformViewBackend', () {
    test('prefers the web backend even on mobile browser target platforms', () {
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: true,
          targetPlatform: TargetPlatform.android,
          desktopTextureId: null,
        ),
        ar_widget.ArEnginePlatformViewBackend.webHtmlElementView,
      );
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: true,
          targetPlatform: TargetPlatform.iOS,
          desktopTextureId: null,
        ),
        ar_widget.ArEnginePlatformViewBackend.webHtmlElementView,
      );
    });

    test('uses native platform views on Android, iOS, and macOS', () {
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: false,
          targetPlatform: TargetPlatform.android,
          desktopTextureId: null,
        ),
        ar_widget.ArEnginePlatformViewBackend.androidPlatformView,
      );
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
          desktopTextureId: null,
        ),
        ar_widget.ArEnginePlatformViewBackend.iosPlatformView,
      );
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: false,
          targetPlatform: TargetPlatform.macOS,
          desktopTextureId: null,
        ),
        ar_widget.ArEnginePlatformViewBackend.macOSPlatformView,
      );
    });

    test('uses a texture only after desktop texture ID is available', () {
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: false,
          targetPlatform: TargetPlatform.windows,
          desktopTextureId: null,
        ),
        ar_widget.ArEnginePlatformViewBackend.loading,
      );
      expect(
        ar_widget.resolveArEnginePlatformViewBackend(
          isWeb: false,
          targetPlatform: TargetPlatform.windows,
          desktopTextureId: 42,
        ),
        ar_widget.ArEnginePlatformViewBackend.desktopTexture,
      );
    });
  });

  group('ARWidget lifecycle', () {
    testWidgets(
        'creates a desktop texture controller and reconfigures on config changes',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform()..nextTextureId = 42;
      final created = <ARController>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      expect(find.byType(Texture), findsOneWidget);
      expect(platform.initConfigs.single.detectHorizontalPlanes, isTrue);

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(
              showFeaturePoints: true,
            ),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      expect(platform.reconfigureConfigs.single.showFeaturePoints, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();

      expect(created.single.isDisposed, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'can resolve configs before creating and reconfiguring sessions',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform(
        TestArEnginePlatform(
          capabilities: const ARCapabilities(
            isARSupported: true,
            supportsWorldTracking: true,
            supportsHitTesting: true,
            supportsHumanOcclusion: true,
          ),
        ),
      )..nextTextureId = 42;
      final resolutions = <ARSessionConfigResolution>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(
              detectVerticalPlanes: true,
              cloudAnchorsEnabled: true,
              targetFrameRate: 30,
              occlusionEnabled: true,
              depthEnabled: true,
            ),
            resolveConfigAgainstCapabilities: true,
            onSessionConfigResolved: resolutions.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(platform.supportChecked, isFalse);
      expect(platform.capabilitiesChecked, isTrue);
      expect(platform.initConfigs.single.detectVerticalPlanes, isFalse);
      expect(platform.initConfigs.single.cloudAnchorsEnabled, isFalse);
      expect(platform.initConfigs.single.depthEnabled, isFalse);
      expect(platform.initConfigs.single.occlusionEnabled, isTrue);
      expect(platform.initConfigs.single.targetFrameRate, 30);
      expect(resolutions.single.hasDegraded, isTrue);
      expect(
        resolutions.single.unsupportedFeatureKeys,
        containsAll(<String>[
          'planeDetection',
          'lightEstimation',
          'cloudAnchors',
          'sceneDepth',
        ]),
      );

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(
              targetFrameRate: 24,
              bodyTrackingEnabled: true,
            ),
            resolveConfigAgainstCapabilities: true,
            onSessionConfigResolved: resolutions.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        platform.reconfigureConfigs.single.detectHorizontalPlanes,
        isFalse,
      );
      expect(platform.reconfigureConfigs.single.bodyTrackingEnabled, isFalse);
      expect(platform.reconfigureConfigs.single.targetFrameRate, 24);
      expect(resolutions, hasLength(2));
      expect(
        resolutions.last.unsupportedFeatureKeys,
        containsAll(<String>[
          'planeDetection',
          'lightEstimation',
          'bodyTracking',
        ]),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('publishes session health snapshots from controller streams',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform(
        TestArEnginePlatform(syncStreams: true),
      )..nextTextureId = 43;
      final health = <ARSessionHealthSnapshot>[];
      final assessments = <ARSessionHealthAssessment>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onSessionHealthChanged: health.add,
            onSessionHealthAssessmentChanged: assessments.add,
            sessionHealthMinPublishInterval: Duration.zero,
            sessionHealthResampleInterval: null,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(health, isNotEmpty);
      expect(assessments, isNotEmpty);
      expect(health.last.status, ARSessionHealthStatus.noCameraFrame);
      expect(assessments.last.severity, ARSessionHealthSeverity.blocked);

      platform.emitCamera(_camera(trackingState: ARTrackingState.tracking));
      platform.emitPlanes(const <ARPlane>[_horizontalPlane]);
      platform.emitAnchor(_anchor);
      platform.emitLight(21);
      await tester.pump();

      expect(health.last.status, ARSessionHealthStatus.tracking);
      expect(health.last.trackedPlaneCount, 1);
      expect(health.last.trackedAnchorCount, 1);
      expect(health.last.lightEstimateLux, 21);
      expect(assessments.last.snapshot, health.last);
      expect(assessments.last.severity, ARSessionHealthSeverity.good);

      final deliveredCount = health.length;
      final assessmentCount = assessments.length;
      await tester.pumpWidget(
        _host(
          const ar_widget.ARWidget(
            config: ARSessionConfig(),
            sessionHealthMinPublishInterval: Duration.zero,
            sessionHealthResampleInterval: null,
            loadingWidget: Text('loading'),
          ),
        ),
      );
      await tester.pump();

      platform.emitCamera(_camera(trackingState: ARTrackingState.paused));
      await tester.pump();

      expect(health, hasLength(deliveredCount));
      expect(assessments, hasLength(assessmentCount));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('publishes live session diagnostics reports', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform(
        TestArEnginePlatform(syncStreams: true),
      )..nextTextureId = 44;
      final reports = <ARDiagnosticsReport>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onSessionDiagnosticsReportChanged: reports.add,
            sessionDiagnosticsReportQuery: const ARDiagnosticsTimelineQuery(
              severity: ARSessionHealthSeverity.good,
            ),
            sessionHealthMinPublishInterval: Duration.zero,
            sessionHealthResampleInterval: null,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(reports, isNotEmpty);
      expect(reports.last.statusLabel, 'No AR diagnostics matches');
      expect(reports.last.timeline.latest?.isBlocked, isTrue);

      platform.emitCamera(_camera(trackingState: ARTrackingState.tracking));
      await tester.pump();

      expect(reports.last.statusLabel, '1 matching AR event healthy');
      expect(
        reports.last.queryResult.events.single.severity,
        ARSessionHealthSeverity.good,
      );
      expect(
        reports.last.latestEvent?.type,
        ARDiagnosticsTimelineEventType.sessionHealth,
      );

      final reportCount = reports.length;
      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onSessionDiagnosticsReportChanged: reports.add,
            sessionDiagnosticsReportQuery: const ARDiagnosticsTimelineQuery(
              severity: ARSessionHealthSeverity.blocked,
            ),
            sessionHealthMinPublishInterval: Duration.zero,
            sessionHealthResampleInterval: null,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();

      expect(reports.length, greaterThan(reportCount));
      expect(reports.last.statusLabel, '1 matching blocked AR event');
      expect(
        reports.last.queryResult.events.single.severity,
        ARSessionHealthSeverity.blocked,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('reconfigures when image target physical width changes',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform()..nextTextureId = 42;
      final created = <ARController>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(
              imageTargets: <ARImageTarget>[
                ARImageTarget(
                  name: 'poster',
                  assetPath: 'assets/poster.png',
                  physicalWidthMeters: 0.3,
                ),
              ],
            ),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(
              imageTargets: <ARImageTarget>[
                ARImageTarget(
                  name: 'poster',
                  assetPath: 'assets/poster.png',
                  physicalWidthMeters: 0.6,
                ),
              ],
            ),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      expect(platform.reconfigureConfigs, hasLength(1));
      expect(
        platform
            .reconfigureConfigs.single.imageTargets.single.physicalWidthMeters,
        0.6,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('reconfigures to the latest config if props change during init',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final initGate = Completer<void>();
      final platform = installPlatform(
        TestArEnginePlatform(initSessionGate: initGate),
      )..nextTextureId = 7;
      final created = <ARController>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(bodyTrackingEnabled: true),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );

      initGate.complete();
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      expect(platform.initConfigs.single.detectHorizontalPlanes, isTrue);
      expect(platform.reconfigureConfigs.single.bodyTrackingEnabled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'disposes a created controller when desktop texture lookup fails',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      installPlatform().getDesktopTextureIdError =
          StateError('texture unavailable');

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            errorBuilder: (context, error) => Text('error: $error'),
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('texture unavailable'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('disposes a controller that finishes after widget removal',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final initGate = Completer<void>();
      installPlatform(
        TestArEnginePlatform(initSessionGate: initGate),
      ).nextTextureId = 9;
      final created = <ARController>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      initGate.complete();
      await tester.pump();
      await tester.pump();

      expect(created, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'maps camera permission platform errors to ARCameraPermissionException',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      installPlatform()
        ..nextTextureId = 8
        ..initSessionError = PlatformException(
          code: 'CAMERA_PERMISSION_DENIED',
          message: 'Camera permission was revoked',
        );

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            errorBuilder: (context, error) => Text(error.runtimeType.toString()),
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('ARCameraPermissionException'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'recreates the native session when resume fails after backgrounding',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform()..nextTextureId = 5;
      final created = <ARController>[];

      await tester.pumpWidget(
        _host(
          ar_widget.ARWidget(
            config: const ARSessionConfig(),
            onARViewCreated: created.add,
            loadingWidget: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      platform.resumeSessionError = StateError('camera session was reclaimed');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump();

      expect(platform.resumeCount, 1);
      expect(platform.initConfigs, hasLength(2));
      expect(created, hasLength(2));
      expect(created.last, isNot(same(created.first)));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'ignores overlapping resumed lifecycle events',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform()..nextTextureId = 6;

      await tester.pumpWidget(
        _host(
          const ar_widget.ARWidget(
            config: ARSessionConfig(),
            loadingWidget: Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();

      expect(platform.resumeCount, 1);
      expect(platform.initConfigs, hasLength(1));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'handles lifecycle pause errors without uncaught async failures',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final platform = installPlatform()
        ..nextTextureId = 5
        ..pauseSessionError = StateError('pause failed');

      await tester.pumpWidget(
        _host(
          const ar_widget.ARWidget(
            config: ARSessionConfig(),
            loadingWidget: Text('loading'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();

      expect(platform.pauseCount, 1);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 240, height: 160, child: child),
    );

ARCamera _camera({
  required ARTrackingState trackingState,
  ARTrackingFailureReason? failureReason,
}) =>
    ARCamera(
      pose: const ARPose.identity(),
      projectionMatrix: ARMatrix4.identity(),
      viewMatrix: ARMatrix4.identity(),
      trackingState: trackingState,
      failureReason: failureReason,
      intrinsics: const <double>[1, 1, 0.5, 0.5],
      imageResolution: const <int>[640, 480],
    );

const _horizontalPlane = ARPlane(
  id: 'floor',
  alignment: ARPlaneAlignment.horizontal,
  centerPose: ARPose.identity(),
  extentMeters: ARVector3(2, 0, 2),
  boundaryVertices: <ARVector3>[
    ARVector3(-1, 0, -1),
    ARVector3(1, 0, -1),
    ARVector3(1, 0, 1),
    ARVector3(-1, 0, 1),
  ],
  trackingState: ARTrackingState.tracking,
);

const _anchor = ARAnchor(
  id: 'tracked_anchor',
  pose: ARPose.identity(),
  trackingState: ARTrackingState.tracking,
);
