import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARSessionFeature', () {
    test('maps stable keys to typed features and labels', () {
      expect(
        ARSessionFeature.fromKey('cloudAnchors'),
        ARSessionFeature.cloudAnchors,
      );
      expect(ARSessionFeature.cloudAnchors.key, 'cloudAnchors');
      expect(ARSessionFeature.cloudAnchors.label, 'Cloud anchors');
      expect(
        ARSessionFeature.labelForKey('geospatial'),
        'Native geospatial',
      );
      expect(ARSessionFeature.fromKey('futureFeature'), isNull);
      expect(ARSessionFeature.labelForKey('futureFeature'), 'futureFeature');
    });
  });

  group('ARCapabilities', () {
    test('reports unsupported session features as typed values and keys', () {
      const capabilities = ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsHitTesting: true,
        supportsHumanOcclusion: true,
      );
      const requested = ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        imageTargets: <ARImageTarget>[
          ARImageTarget(
            name: 'poster',
            assetPath: 'poster.png',
            physicalWidthMeters: 0.3,
          ),
        ],
        occlusionEnabled: true,
        depthEnabled: true,
        bodyTrackingEnabled: true,
        geospatialEnabled: true,
      );

      expect(
        capabilities.unsupportedSessionFeaturesFor(requested),
        <ARSessionFeature>[
          ARSessionFeature.planeDetection,
          ARSessionFeature.lightEstimation,
          ARSessionFeature.imageTracking,
          ARSessionFeature.cloudAnchors,
          ARSessionFeature.sceneDepth,
          ARSessionFeature.bodyTracking,
          ARSessionFeature.geospatial,
        ],
      );
      expect(
        capabilities.unsupportedFeaturesFor(requested),
        <String>[
          'planeDetection',
          'lightEstimation',
          'imageTracking',
          'cloudAnchors',
          'sceneDepth',
          'bodyTracking',
          'geospatial',
        ],
      );
    });

    test('resolution exposes typed features and labels beside string keys', () {
      const requested = ARSessionConfig(
        cloudAnchorsEnabled: true,
        geospatialEnabled: true,
      );
      final resolution = const ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsHitTesting: true,
      ).resolveConfig(requested);

      expect(
        resolution.unsupportedFeatures,
        <ARSessionFeature>[
          ARSessionFeature.planeDetection,
          ARSessionFeature.lightEstimation,
          ARSessionFeature.cloudAnchors,
          ARSessionFeature.geospatial,
        ],
      );
      expect(
        resolution.unsupportedFeatureLabels,
        <String>[
          'Plane detection',
          'Light estimation',
          'Cloud anchors',
          'Native geospatial',
        ],
      );

      final futureResolution = ARSessionConfigResolution(
        requestedConfig: requested,
        resolvedConfig: requested,
        unsupportedFeatureKeys: const <String>[
          'cloudAnchors',
          'futureFeature',
        ],
      );

      expect(
        futureResolution.unsupportedFeatures,
        <ARSessionFeature>[ARSessionFeature.cloudAnchors],
      );
      expect(
        futureResolution.unsupportedFeatureLabels,
        <String>['Cloud anchors', 'futureFeature'],
      );
    });

    test('resolution can be copied and serialized for diagnostics', () {
      const requested = ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        geospatialEnabled: true,
        targetFrameRate: 30,
      );
      final resolution = const ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsHitTesting: true,
      ).resolveConfig(requested);

      final roundTripped = ARSessionConfigResolution.fromMap(
        resolution.toMap(),
      );
      final edited = resolution.copyWith(
        unsupportedFeatureKeys: const <String>['cloudAnchors'],
      );

      expect(roundTripped, resolution);
      expect(roundTripped.hashCode, resolution.hashCode);
      expect(roundTripped.requestedConfig.targetFrameRate, 30);
      expect(roundTripped.resolvedConfig.cloudAnchorsEnabled, isFalse);
      expect(edited.unsupportedFeatureKeys, <String>['cloudAnchors']);
      expect(edited.requestedConfig, resolution.requestedConfig);
      expect(edited.resolvedConfig, resolution.resolvedConfig);
    });
  });
}
