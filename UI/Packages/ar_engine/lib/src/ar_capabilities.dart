import 'ar_session_config.dart';

/// Session-level features that may be requested by [ARSessionConfig].
///
/// The stable [key] values are kept as strings for platform messages,
/// diagnostics payloads, and older app code.
enum ARSessionFeature {
  ar('ar', 'AR session'),
  planeDetection('planeDetection', 'Plane detection'),
  lightEstimation('lightEstimation', 'Light estimation'),
  imageTracking('imageTracking', 'Image tracking'),
  cloudAnchors('cloudAnchors', 'Cloud anchors'),
  sceneDepth('sceneDepth', 'Scene depth'),
  occlusion('occlusion', 'Occlusion'),
  bodyTracking('bodyTracking', 'Body tracking'),
  geospatial('geospatial', 'Native geospatial');

  const ARSessionFeature(this.key, this.label);

  final String key;
  final String label;

  static ARSessionFeature? fromKey(String key) {
    for (final feature in values) {
      if (feature.key == key) {
        return feature;
      }
    }
    return null;
  }

  static String labelForKey(String key) => fromKey(key)?.label ?? key;
}

/// Platform feature support reported by the active ar_engine backend.
///
/// [isARSupported] is the coarse session-level gate. The remaining fields let
/// apps decide whether optional systems should be enabled, hidden, or offered
/// with a fallback path.
class ARCapabilities {
  const ARCapabilities({
    required this.isARSupported,
    this.supportsWorldTracking = false,
    this.supportsPlaneDetection = false,
    this.supportsHitTesting = false,
    this.supportsImageTracking = false,
    this.supportsLightEstimation = false,
    this.supportsSceneDepth = false,
    this.supportsHumanOcclusion = false,
    this.supportsBodyTracking = false,
    this.supportsGeospatial = false,
    this.supportsCloudAnchors = false,
    this.supportsSnapshotCapture = false,
    this.supportsRecordingEncode = false,
  });

  const ARCapabilities.unsupported()
      : isARSupported = false,
        supportsWorldTracking = false,
        supportsPlaneDetection = false,
        supportsHitTesting = false,
        supportsImageTracking = false,
        supportsLightEstimation = false,
        supportsSceneDepth = false,
        supportsHumanOcclusion = false,
        supportsBodyTracking = false,
        supportsGeospatial = false,
        supportsCloudAnchors = false,
        supportsSnapshotCapture = false,
        supportsRecordingEncode = false;

  factory ARCapabilities.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const ARCapabilities.unsupported();
    return ARCapabilities(
      isARSupported: _bool(map, 'isARSupported'),
      supportsWorldTracking: _bool(map, 'supportsWorldTracking'),
      supportsPlaneDetection: _bool(map, 'supportsPlaneDetection'),
      supportsHitTesting: _bool(map, 'supportsHitTesting'),
      supportsImageTracking: _bool(map, 'supportsImageTracking'),
      supportsLightEstimation: _bool(map, 'supportsLightEstimation'),
      supportsSceneDepth: _bool(map, 'supportsSceneDepth'),
      supportsHumanOcclusion: _bool(map, 'supportsHumanOcclusion'),
      supportsBodyTracking: _bool(map, 'supportsBodyTracking'),
      supportsGeospatial: _bool(map, 'supportsGeospatial'),
      supportsCloudAnchors: _bool(map, 'supportsCloudAnchors'),
      supportsSnapshotCapture: _bool(map, 'supportsSnapshotCapture'),
      supportsRecordingEncode: _bool(map, 'supportsRecordingEncode'),
    );
  }

  final bool isARSupported;
  final bool supportsWorldTracking;
  final bool supportsPlaneDetection;
  final bool supportsHitTesting;
  final bool supportsImageTracking;
  final bool supportsLightEstimation;
  final bool supportsSceneDepth;
  final bool supportsHumanOcclusion;
  final bool supportsBodyTracking;
  final bool supportsGeospatial;
  final bool supportsCloudAnchors;
  final bool supportsSnapshotCapture;
  final bool supportsRecordingEncode;

  bool get supportsAnyOcclusion => supportsSceneDepth || supportsHumanOcclusion;

  bool get supportsCoreSession =>
      isARSupported && supportsWorldTracking && supportsHitTesting;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'isARSupported': isARSupported,
        'supportsWorldTracking': supportsWorldTracking,
        'supportsPlaneDetection': supportsPlaneDetection,
        'supportsHitTesting': supportsHitTesting,
        'supportsImageTracking': supportsImageTracking,
        'supportsLightEstimation': supportsLightEstimation,
        'supportsSceneDepth': supportsSceneDepth,
        'supportsHumanOcclusion': supportsHumanOcclusion,
        'supportsBodyTracking': supportsBodyTracking,
        'supportsGeospatial': supportsGeospatial,
        'supportsCloudAnchors': supportsCloudAnchors,
        'supportsSnapshotCapture': supportsSnapshotCapture,
        'supportsRecordingEncode': supportsRecordingEncode,
      };

  ARCapabilities copyWith({
    bool? isARSupported,
    bool? supportsWorldTracking,
    bool? supportsPlaneDetection,
    bool? supportsHitTesting,
    bool? supportsImageTracking,
    bool? supportsLightEstimation,
    bool? supportsSceneDepth,
    bool? supportsHumanOcclusion,
    bool? supportsBodyTracking,
    bool? supportsGeospatial,
    bool? supportsCloudAnchors,
    bool? supportsSnapshotCapture,
    bool? supportsRecordingEncode,
  }) =>
      ARCapabilities(
        isARSupported: isARSupported ?? this.isARSupported,
        supportsWorldTracking:
            supportsWorldTracking ?? this.supportsWorldTracking,
        supportsPlaneDetection:
            supportsPlaneDetection ?? this.supportsPlaneDetection,
        supportsHitTesting: supportsHitTesting ?? this.supportsHitTesting,
        supportsImageTracking:
            supportsImageTracking ?? this.supportsImageTracking,
        supportsLightEstimation:
            supportsLightEstimation ?? this.supportsLightEstimation,
        supportsSceneDepth: supportsSceneDepth ?? this.supportsSceneDepth,
        supportsHumanOcclusion:
            supportsHumanOcclusion ?? this.supportsHumanOcclusion,
        supportsBodyTracking: supportsBodyTracking ?? this.supportsBodyTracking,
        supportsGeospatial: supportsGeospatial ?? this.supportsGeospatial,
        supportsCloudAnchors: supportsCloudAnchors ?? this.supportsCloudAnchors,
        supportsSnapshotCapture:
            supportsSnapshotCapture ?? this.supportsSnapshotCapture,
        supportsRecordingEncode:
            supportsRecordingEncode ?? this.supportsRecordingEncode,
      );

  /// Returns features from [config] that this backend cannot satisfy natively.
  List<ARSessionFeature> unsupportedSessionFeaturesFor(
    ARSessionConfig config,
  ) {
    final missing = <ARSessionFeature>[];
    if (!isARSupported) {
      missing.add(ARSessionFeature.ar);
      return missing;
    }
    if ((config.detectHorizontalPlanes || config.detectVerticalPlanes) &&
        !supportsPlaneDetection) {
      missing.add(ARSessionFeature.planeDetection);
    }
    if (config.lightingEstimationEnabled && !supportsLightEstimation) {
      missing.add(ARSessionFeature.lightEstimation);
    }
    if (config.imageTargets.isNotEmpty && !supportsImageTracking) {
      missing.add(ARSessionFeature.imageTracking);
    }
    if (config.cloudAnchorsEnabled && !supportsCloudAnchors) {
      missing.add(ARSessionFeature.cloudAnchors);
    }
    if (config.depthEnabled && !supportsSceneDepth) {
      missing.add(ARSessionFeature.sceneDepth);
    }
    if (config.occlusionEnabled && !supportsAnyOcclusion) {
      missing.add(ARSessionFeature.occlusion);
    }
    if (config.bodyTrackingEnabled && !supportsBodyTracking) {
      missing.add(ARSessionFeature.bodyTracking);
    }
    if (config.geospatialEnabled && !supportsGeospatial) {
      missing.add(ARSessionFeature.geospatial);
    }
    return missing;
  }

  /// Returns stable feature keys from [config] that this backend cannot satisfy
  /// natively.
  List<String> unsupportedFeaturesFor(ARSessionConfig config) =>
      unsupportedSessionFeaturesFor(config)
          .map((feature) => feature.key)
          .toList(growable: false);

  bool supportsConfig(ARSessionConfig config) =>
      unsupportedFeaturesFor(config).isEmpty;

  /// Returns a best-effort session config for this backend.
  ///
  /// Unsupported optional systems are disabled while neutral options such as
  /// [ARSessionConfig.targetFrameRate] are preserved. This lets apps express
  /// their ideal AR session once, then pass a compatible config to [ARWidget]
  /// or [ARController.create].
  ARSessionConfig compatibleConfigFor(ARSessionConfig requested) {
    if (!isARSupported) {
      return requested.copyWith(
        detectHorizontalPlanes: false,
        detectVerticalPlanes: false,
        lightingEstimationEnabled: false,
        cloudAnchorsEnabled: false,
        imageTargets: const <ARImageTarget>[],
        showFeaturePoints: false,
        occlusionEnabled: false,
        depthEnabled: false,
        bodyTrackingEnabled: false,
        geospatialEnabled: false,
      );
    }

    return requested.copyWith(
      detectHorizontalPlanes:
          requested.detectHorizontalPlanes && supportsPlaneDetection,
      detectVerticalPlanes:
          requested.detectVerticalPlanes && supportsPlaneDetection,
      lightingEstimationEnabled:
          requested.lightingEstimationEnabled && supportsLightEstimation,
      cloudAnchorsEnabled:
          requested.cloudAnchorsEnabled && supportsCloudAnchors,
      imageTargets: supportsImageTracking
          ? requested.imageTargets
          : const <ARImageTarget>[],
      occlusionEnabled: requested.occlusionEnabled && supportsAnyOcclusion,
      depthEnabled: requested.depthEnabled && supportsSceneDepth,
      bodyTrackingEnabled:
          requested.bodyTrackingEnabled && supportsBodyTracking,
      geospatialEnabled: requested.geospatialEnabled && supportsGeospatial,
    );
  }

  /// Resolves [requested] against this backend and reports what changed.
  ARSessionConfigResolution resolveConfig(ARSessionConfig requested) =>
      ARSessionConfigResolution(
        requestedConfig: requested,
        resolvedConfig: compatibleConfigFor(requested),
        unsupportedFeatureKeys: unsupportedFeaturesFor(requested),
      );

  @override
  bool operator ==(Object other) =>
      other is ARCapabilities &&
      isARSupported == other.isARSupported &&
      supportsWorldTracking == other.supportsWorldTracking &&
      supportsPlaneDetection == other.supportsPlaneDetection &&
      supportsHitTesting == other.supportsHitTesting &&
      supportsImageTracking == other.supportsImageTracking &&
      supportsLightEstimation == other.supportsLightEstimation &&
      supportsSceneDepth == other.supportsSceneDepth &&
      supportsHumanOcclusion == other.supportsHumanOcclusion &&
      supportsBodyTracking == other.supportsBodyTracking &&
      supportsGeospatial == other.supportsGeospatial &&
      supportsCloudAnchors == other.supportsCloudAnchors &&
      supportsSnapshotCapture == other.supportsSnapshotCapture &&
      supportsRecordingEncode == other.supportsRecordingEncode;

  @override
  int get hashCode => Object.hash(
        isARSupported,
        supportsWorldTracking,
        supportsPlaneDetection,
        supportsHitTesting,
        supportsImageTracking,
        supportsLightEstimation,
        supportsSceneDepth,
        supportsHumanOcclusion,
        supportsBodyTracking,
        supportsGeospatial,
        supportsCloudAnchors,
        supportsSnapshotCapture,
        supportsRecordingEncode,
      );

  @override
  String toString() => 'ARCapabilities('
      'supported:$isARSupported world:$supportsWorldTracking '
      'planes:$supportsPlaneDetection hitTest:$supportsHitTesting '
      'image:$supportsImageTracking light:$supportsLightEstimation '
      'depth:$supportsSceneDepth human:$supportsHumanOcclusion '
      'body:$supportsBodyTracking geo:$supportsGeospatial '
      'cloud:$supportsCloudAnchors snapshot:$supportsSnapshotCapture '
      'recording:$supportsRecordingEncode)';

  static bool _bool(Map<dynamic, dynamic> map, String key) =>
      map[key] as bool? ?? false;
}

/// Result of resolving an ideal [ARSessionConfig] against platform support.
class ARSessionConfigResolution {
  ARSessionConfigResolution({
    required this.requestedConfig,
    required this.resolvedConfig,
    required Iterable<String> unsupportedFeatureKeys,
  }) : unsupportedFeatureKeys =
            List<String>.unmodifiable(unsupportedFeatureKeys);

  factory ARSessionConfigResolution.fromMap(Map<dynamic, dynamic> map) =>
      ARSessionConfigResolution(
        requestedConfig: ARSessionConfig.fromMap(
          map['requestedConfig'] as Map<dynamic, dynamic>,
        ),
        resolvedConfig: ARSessionConfig.fromMap(
          map['resolvedConfig'] as Map<dynamic, dynamic>,
        ),
        unsupportedFeatureKeys:
            (map['unsupportedFeatureKeys'] as List<dynamic>? ??
                    const <dynamic>[])
                .map((key) => key.toString()),
      );

  /// The app-requested session config before capability negotiation.
  final ARSessionConfig requestedConfig;

  /// The best-effort config this backend can run.
  final ARSessionConfig resolvedConfig;

  /// Feature keys requested by [requestedConfig] but unsupported by the backend.
  final List<String> unsupportedFeatureKeys;

  /// Typed features requested by [requestedConfig] but unsupported by the
  /// backend. Unknown future keys are omitted here but remain available through
  /// [unsupportedFeatureKeys].
  List<ARSessionFeature> get unsupportedFeatures {
    final features = <ARSessionFeature>[];
    for (final key in unsupportedFeatureKeys) {
      final feature = ARSessionFeature.fromKey(key);
      if (feature != null) {
        features.add(feature);
      }
    }
    return List<ARSessionFeature>.unmodifiable(features);
  }

  /// User-facing labels for [unsupportedFeatureKeys].
  List<String> get unsupportedFeatureLabels => List<String>.unmodifiable(
        unsupportedFeatureKeys.map(ARSessionFeature.labelForKey),
      );

  bool get isFullySupported => unsupportedFeatureKeys.isEmpty;

  bool get hasDegraded => requestedConfig != resolvedConfig;

  ARSessionConfigResolution copyWith({
    ARSessionConfig? requestedConfig,
    ARSessionConfig? resolvedConfig,
    Iterable<String>? unsupportedFeatureKeys,
  }) =>
      ARSessionConfigResolution(
        requestedConfig: requestedConfig ?? this.requestedConfig,
        resolvedConfig: resolvedConfig ?? this.resolvedConfig,
        unsupportedFeatureKeys:
            unsupportedFeatureKeys ?? this.unsupportedFeatureKeys,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'requestedConfig': requestedConfig.toMap(),
        'resolvedConfig': resolvedConfig.toMap(),
        'unsupportedFeatureKeys': unsupportedFeatureKeys,
      };

  @override
  bool operator ==(Object other) =>
      other is ARSessionConfigResolution &&
      requestedConfig == other.requestedConfig &&
      resolvedConfig == other.resolvedConfig &&
      _stringListsEqual(
        unsupportedFeatureKeys,
        other.unsupportedFeatureKeys,
      );

  @override
  int get hashCode => Object.hash(
        requestedConfig,
        resolvedConfig,
        Object.hashAll(unsupportedFeatureKeys),
      );

  @override
  String toString() => 'ARSessionConfigResolution('
      'fullySupported:$isFullySupported '
      'degraded:$hasDegraded '
      'unsupported:$unsupportedFeatureKeys)';
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
