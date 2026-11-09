import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  test('AR viewer session config enables supported native features', () async {
    final container = ProviderContainer(
      overrides: [
        arViewerCapabilitiesProvider.overrideWith((ref) async {
          return const JejakuARCapabilities(
            engine: ARCapabilities(
              isARSupported: true,
              supportsWorldTracking: true,
              supportsPlaneDetection: true,
              supportsHitTesting: true,
              supportsLightEstimation: true,
              supportsSceneDepth: true,
              supportsHumanOcclusion: true,
              supportsGeospatial: true,
              supportsCloudAnchors: true,
              supportsSnapshotCapture: true,
              supportsRecordingEncode: true,
            ),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    final config = await container.read(arViewerSessionConfigProvider.future);
    final plan = await container.read(arViewerSessionPlanProvider.future);

    expect(config.detectHorizontalPlanes, isTrue);
    expect(config.detectVerticalPlanes, isTrue);
    expect(config.lightingEstimationEnabled, isTrue);
    expect(config.geospatialEnabled, isTrue);
    expect(config.cloudAnchorsEnabled, isFalse);
    expect(config.depthEnabled, isFalse);
    expect(config.occlusionEnabled, isFalse);
    expect(plan.preferredConfig, config);
    expect(plan.compatibleConfig, config);
    expect(plan.isFullySupported, isTrue);
  });

  test(
      'AR viewer session config keeps preferred features for downgrade reports',
      () async {
    const engine = ARCapabilities(
      isARSupported: true,
      supportsWorldTracking: true,
      supportsHitTesting: true,
      supportsSnapshotCapture: true,
    );
    final container = ProviderContainer(
      overrides: [
        arViewerCapabilitiesProvider.overrideWith((ref) async {
          return const JejakuARCapabilities(
            engine: engine,
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    final config = await container.read(arViewerSessionConfigProvider.future);
    final plan = await container.read(arViewerSessionPlanProvider.future);

    expect(config.detectHorizontalPlanes, isTrue);
    expect(config.detectVerticalPlanes, isTrue);
    expect(config.lightingEstimationEnabled, isTrue);
    expect(config.geospatialEnabled, isTrue);
    expect(config.cloudAnchorsEnabled, isFalse);
    expect(config.depthEnabled, isFalse);
    expect(config.occlusionEnabled, isFalse);
    expect(
      engine.resolveConfig(config).unsupportedFeatureKeys,
      <String>[
        'planeDetection',
        'lightEstimation',
        'geospatial',
      ],
    );
    expect(plan.preferredConfig, config);
    expect(plan.compatibleConfig.detectHorizontalPlanes, isFalse);
    expect(plan.compatibleConfig.cloudAnchorsEnabled, isFalse);
    expect(plan.hasNativeDowngrades, isTrue);
    expect(
      plan.unsupportedFeatureLabels,
      <String>[
        'Plane detection',
        'Light estimation',
        'Native geospatial',
      ],
    );
  });
}
