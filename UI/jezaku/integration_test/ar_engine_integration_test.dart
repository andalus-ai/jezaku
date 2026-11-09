import 'package:ar_engine/ar_engine.dart';
import 'package:ar_engine_testkit/ar_engine_testkit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ArEngineTestHarness arHarness;

  setUp(() {
    arHarness = ArEngineTestHarness.install();
  });

  tearDown(() {
    arHarness.restore();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Jejaku can create and populate an ar_engine session',
      (tester) async {
    final platform = arHarness.platform;

    final session = await arHarness.createResolvedController(
      const ARSessionConfig(
        detectHorizontalPlanes: true,
        detectVerticalPlanes: true,
        lightingEstimationEnabled: true,
      ),
    );
    final controller = session.controller;

    final scene = JejakuMemoryARScene(controller: controller);
    final result = await scene.syncMemories(
      origin: const JejakuGeoOrigin(
        latitude: -6.9175,
        longitude: 107.6191,
        altitudeMeters: 700,
      ),
      memories: const [
        JejakuGeoAnchor(
          id: 'integration_memory',
          title: 'Integration memory',
          caption: 'Placed through jezaku_ar.',
          latitude: -6.9174,
          longitude: 107.6192,
          altitudeMeters: 701.2,
          headingDegrees: 45,
        ),
      ],
    );
    final placed = result.added.single;

    expect(platform.initConfig?.detectVerticalPlanes, isTrue);
    expect(platform.initConfig, session.resolvedConfig);
    expect(session.isFullySupported, isTrue);
    expect(result.hasChanges, isTrue);
    expect(
      controller.getAnchor(placed.anchorId)?.pose.position.y,
      closeTo(1.2, 1e-9),
    );
    expect(controller.getNode(placed.nodeId)?.metadata['kind'], 'geo_memory');
    expect(
      platform.nodes[placed.nodeId]?.metadata['anchorId'],
      placed.anchorId,
    );

    await session.dispose();

    expect(platform.destroyed, isTrue);
  });

  testWidgets('Jejaku can mount ARWidget through the public testkit',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final platform = arHarness.platform..nextTextureId = 314;
      final created = <ARController>[];
      final resolutions = <ARSessionConfigResolution>[];

      await tester.pumpWidget(
        _integrationHost(
          ARWidget(
            config: const ARSessionConfig(
              detectHorizontalPlanes: true,
              cloudAnchorsEnabled: true,
            ),
            resolveConfigAgainstCapabilities: true,
            onSessionConfigResolved: resolutions.add,
            onARViewCreated: created.add,
            loadingWidget: const Text('loading-ar'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      expect(find.byType(Texture), findsOneWidget);
      expect(platform.initConfigs.single.cloudAnchorsEnabled, isFalse);
      expect(resolutions.single.unsupportedFeatureKeys, ['cloudAnchors']);

      await tester.pumpWidget(
        _integrationHost(
          ARWidget(
            config: const ARSessionConfig(
              detectHorizontalPlanes: true,
              cloudAnchorsEnabled: true,
              bodyTrackingEnabled: true,
            ),
            resolveConfigAgainstCapabilities: true,
            onSessionConfigResolved: resolutions.add,
            onARViewCreated: created.add,
            loadingWidget: const Text('loading-ar'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(created, hasLength(1));
      expect(platform.reconfigureConfigs.single.bodyTrackingEnabled, isFalse);
      expect(
        resolutions.last.unsupportedFeatureKeys,
        ['cloudAnchors', 'bodyTracking'],
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();

      expect(created.single.isDisposed, isTrue);
      expect(platform.destroyCount, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _integrationHost(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 320, height: 240, child: child),
  );
}
