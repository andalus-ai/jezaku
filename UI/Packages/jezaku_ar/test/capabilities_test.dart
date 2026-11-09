import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  group('JejakuARCapabilities', () {
    test('reports native geospatial and native recording encode', () {
      const engine = ARCapabilities(
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
      );

      const capabilities = JejakuARCapabilities(engine: engine);
      final config = capabilities.recommendedSessionConfig(
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
        detectVerticalPlanes: true,
        targetFrameRate: 30,
      );
      final plan = capabilities.planSession(
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
        detectVerticalPlanes: true,
        targetFrameRate: 30,
      );

      expect(capabilities.canStartSession, isTrue);
      expect(capabilities.canPlaceMemories, isTrue);
      expect(
          capabilities.placementMode, JejakuARPlacementMode.nativeGeospatial);
      expect(capabilities.recordingMode, JejakuARRecordingMode.nativeEncode);
      expect(capabilities.activeFallbacks, isEmpty);
      expect(config.geospatialEnabled, isTrue);
      expect(config.cloudAnchorsEnabled, isTrue);
      expect(config.depthEnabled, isTrue);
      expect(config.occlusionEnabled, isTrue);
      expect(config.detectVerticalPlanes, isTrue);
      expect(config.targetFrameRate, 30);
      expect(plan.isFullySupported, isTrue);
      expect(plan.hasNativeDowngrades, isFalse);
      expect(plan.preferredConfig, config);
      expect(plan.recommendedConfig, config);
      expect(plan.compatibleConfig, config);
      expect(plan.unsupportedFeatureLabels, isEmpty);
    });

    test('keeps preferred config observable before compatibility fallback', () {
      const engine = ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsPlaneDetection: true,
        supportsHitTesting: true,
        supportsLightEstimation: true,
        supportsSnapshotCapture: true,
      );

      const capabilities = JejakuARCapabilities(engine: engine);
      final preferred = capabilities.preferredSessionConfig(
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
      );
      final config = capabilities.recommendedSessionConfig(
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
      );
      final resolution = capabilities.resolveSessionConfig(
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
      );
      final plan = capabilities.planSession(
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
      );

      expect(
        capabilities.placementMode,
        JejakuARPlacementMode.localProjectionFallback,
      );
      expect(capabilities.recordingMode, JejakuARRecordingMode.dartFallback);
      expect(
        capabilities.activeFallbacks,
        containsAll(<JejakuARFallback>[
          JejakuARFallback.localGeospatialProjection,
          JejakuARFallback.dartRecordingEncode,
          JejakuARFallback.noSceneDepth,
          JejakuARFallback.noCloudAnchors,
        ]),
      );
      expect(preferred.geospatialEnabled, isTrue);
      expect(preferred.cloudAnchorsEnabled, isTrue);
      expect(preferred.depthEnabled, isTrue);
      expect(preferred.occlusionEnabled, isTrue);
      expect(config.geospatialEnabled, isFalse);
      expect(config.cloudAnchorsEnabled, isFalse);
      expect(config.depthEnabled, isFalse);
      expect(config.occlusionEnabled, isFalse);
      expect(config.detectHorizontalPlanes, isTrue);
      expect(config.lightingEstimationEnabled, isTrue);
      expect(resolution.resolvedConfig, config);
      expect(plan.preferredConfig, preferred);
      expect(plan.recommendedConfig, config);
      expect(plan.compatibleConfig, config);
      expect(plan.hasNativeDowngrades, isTrue);
      expect(plan.activeFallbacks, capabilities.activeFallbacks);
      expect(
        plan.unsupportedFeatures,
        containsAll(<ARSessionFeature>[
          ARSessionFeature.cloudAnchors,
          ARSessionFeature.sceneDepth,
          ARSessionFeature.occlusion,
          ARSessionFeature.geospatial,
        ]),
      );
      expect(
        plan.unsupportedFeatureLabels,
        containsAll(<String>[
          'Cloud anchors',
          'Scene depth',
          'Occlusion',
          'Native geospatial',
        ]),
      );
      expect(
        resolution.unsupportedFeatureKeys,
        containsAll(<String>[
          'cloudAnchors',
          'sceneDepth',
          'occlusion',
          'geospatial',
        ]),
      );
    });

    test('keeps session config quiet when AR is unavailable', () {
      const capabilities = JejakuARCapabilities(
        engine: ARCapabilities.unsupported(),
      );

      final config = capabilities.recommendedSessionConfig(
        detectHorizontalPlanes: true,
        detectVerticalPlanes: true,
        lightingEstimationEnabled: true,
        preferNativeGeospatial: true,
        preferCloudAnchors: true,
        preferDepth: true,
        preferOcclusion: true,
      );

      expect(capabilities.canStartSession, isFalse);
      expect(capabilities.placementMode, JejakuARPlacementMode.unavailable);
      expect(capabilities.recordingMode, JejakuARRecordingMode.unavailable);
      expect(
        capabilities.unavailableFeatureKeys,
        containsAll(<String>[
          'arSession',
          'memoryPlacement',
          'snapshotCapture',
          'recording',
          'sceneDepth',
          'cloudAnchors',
        ]),
      );
      expect(config.detectHorizontalPlanes, isFalse);
      expect(config.detectVerticalPlanes, isFalse);
      expect(config.lightingEstimationEnabled, isFalse);
      expect(config.geospatialEnabled, isFalse);
      expect(config.cloudAnchorsEnabled, isFalse);
      expect(config.depthEnabled, isFalse);
      expect(config.occlusionEnabled, isFalse);
    });
  });
}
