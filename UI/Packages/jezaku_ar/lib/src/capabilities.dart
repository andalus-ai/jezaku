import 'package:ar_engine/ar_engine.dart';

enum JejakuARPlacementMode {
  unavailable,
  localProjectionFallback,
  nativeGeospatial,
}

enum JejakuARRecordingMode {
  unavailable,
  dartFallback,
  nativeEncode,
}

enum JejakuARFallback {
  localGeospatialProjection,
  dartRecordingEncode,
  noSceneDepth,
  noCloudAnchors,
}

class JejakuARSessionPlan {
  const JejakuARSessionPlan({
    required this.capabilities,
    required this.resolution,
  });

  final JejakuARCapabilities capabilities;
  final ARSessionConfigResolution resolution;

  ARSessionConfig get preferredConfig => resolution.requestedConfig;

  ARSessionConfig get recommendedConfig => resolution.resolvedConfig;

  ARSessionConfig get compatibleConfig => resolution.resolvedConfig;

  List<ARSessionFeature> get unsupportedFeatures =>
      resolution.unsupportedFeatures;

  List<String> get unsupportedFeatureKeys => resolution.unsupportedFeatureKeys;

  List<String> get unsupportedFeatureLabels =>
      resolution.unsupportedFeatureLabels;

  List<JejakuARFallback> get activeFallbacks => capabilities.activeFallbacks;

  bool get isFullySupported => resolution.isFullySupported;

  bool get hasNativeDowngrades => resolution.hasDegraded;
}

class JejakuARCapabilities {
  const JejakuARCapabilities({
    required this.engine,
  });

  final ARCapabilities engine;

  static Future<JejakuARCapabilities> query() async {
    return JejakuARCapabilities(
      engine: await ARController.queryCapabilities(),
    );
  }

  static Future<JejakuARCapabilities> fromController(
    ARController controller,
  ) async {
    return JejakuARCapabilities(
      engine: await controller.capabilities,
    );
  }

  bool get canStartSession => engine.isARSupported;

  bool get canPlaceMemories {
    return engine.isARSupported && engine.supportsWorldTracking;
  }

  JejakuARPlacementMode get placementMode {
    if (!canPlaceMemories) {
      return JejakuARPlacementMode.unavailable;
    }
    return engine.supportsGeospatial
        ? JejakuARPlacementMode.nativeGeospatial
        : JejakuARPlacementMode.localProjectionFallback;
  }

  bool get usesNativeGeospatial {
    return placementMode == JejakuARPlacementMode.nativeGeospatial;
  }

  bool get usesLocalProjectionFallback {
    return placementMode == JejakuARPlacementMode.localProjectionFallback;
  }

  bool get canUseDepthCues => engine.supportsSceneDepth;

  bool get canUseHumanOcclusion => engine.supportsHumanOcclusion;

  bool get canPersistCloudAnchors => engine.supportsCloudAnchors;

  bool get canCaptureSnapshots => engine.supportsSnapshotCapture;

  bool get canRecord => recordingMode != JejakuARRecordingMode.unavailable;

  bool get canEncodeRecordingsNatively => engine.supportsRecordingEncode;

  JejakuARRecordingMode get recordingMode {
    if (!engine.supportsSnapshotCapture) {
      return JejakuARRecordingMode.unavailable;
    }
    return engine.supportsRecordingEncode
        ? JejakuARRecordingMode.nativeEncode
        : JejakuARRecordingMode.dartFallback;
  }

  List<JejakuARFallback> get activeFallbacks {
    return <JejakuARFallback>[
      if (usesLocalProjectionFallback)
        JejakuARFallback.localGeospatialProjection,
      if (recordingMode == JejakuARRecordingMode.dartFallback)
        JejakuARFallback.dartRecordingEncode,
      if (!canUseDepthCues) JejakuARFallback.noSceneDepth,
      if (!canPersistCloudAnchors) JejakuARFallback.noCloudAnchors,
    ];
  }

  List<String> get unavailableFeatureKeys {
    return <String>[
      if (!canStartSession) 'arSession',
      if (!canPlaceMemories) 'memoryPlacement',
      if (!canCaptureSnapshots) 'snapshotCapture',
      if (recordingMode == JejakuARRecordingMode.unavailable) 'recording',
      if (!canUseDepthCues) 'sceneDepth',
      if (!canPersistCloudAnchors) 'cloudAnchors',
    ];
  }

  ARSessionConfig preferredSessionConfig({
    bool detectHorizontalPlanes = true,
    bool detectVerticalPlanes = false,
    bool lightingEstimationEnabled = true,
    bool preferNativeGeospatial = true,
    bool preferCloudAnchors = false,
    bool preferDepth = false,
    bool preferOcclusion = false,
    int? targetFrameRate,
  }) {
    return ARSessionConfig(
      detectHorizontalPlanes: detectHorizontalPlanes,
      detectVerticalPlanes: detectVerticalPlanes,
      lightingEstimationEnabled: lightingEstimationEnabled,
      cloudAnchorsEnabled: preferCloudAnchors,
      targetFrameRate: targetFrameRate,
      occlusionEnabled: preferOcclusion,
      depthEnabled: preferDepth,
      geospatialEnabled: preferNativeGeospatial,
    );
  }

  JejakuARSessionPlan planSession({
    bool detectHorizontalPlanes = true,
    bool detectVerticalPlanes = false,
    bool lightingEstimationEnabled = true,
    bool preferNativeGeospatial = true,
    bool preferCloudAnchors = false,
    bool preferDepth = false,
    bool preferOcclusion = false,
    int? targetFrameRate,
  }) {
    final preferred = preferredSessionConfig(
      detectHorizontalPlanes: detectHorizontalPlanes,
      detectVerticalPlanes: detectVerticalPlanes,
      lightingEstimationEnabled: lightingEstimationEnabled,
      preferNativeGeospatial: preferNativeGeospatial,
      preferCloudAnchors: preferCloudAnchors,
      preferDepth: preferDepth,
      preferOcclusion: preferOcclusion,
      targetFrameRate: targetFrameRate,
    );
    return JejakuARSessionPlan(
      capabilities: this,
      resolution: engine.resolveConfig(preferred),
    );
  }

  ARSessionConfig recommendedSessionConfig({
    bool detectHorizontalPlanes = true,
    bool detectVerticalPlanes = false,
    bool lightingEstimationEnabled = true,
    bool preferNativeGeospatial = true,
    bool preferCloudAnchors = false,
    bool preferDepth = false,
    bool preferOcclusion = false,
    int? targetFrameRate,
  }) {
    return planSession(
      detectHorizontalPlanes: detectHorizontalPlanes,
      detectVerticalPlanes: detectVerticalPlanes,
      lightingEstimationEnabled: lightingEstimationEnabled,
      preferNativeGeospatial: preferNativeGeospatial,
      preferCloudAnchors: preferCloudAnchors,
      preferDepth: preferDepth,
      preferOcclusion: preferOcclusion,
      targetFrameRate: targetFrameRate,
    ).recommendedConfig;
  }

  ARSessionConfigResolution resolveSessionConfig({
    bool detectHorizontalPlanes = true,
    bool detectVerticalPlanes = false,
    bool lightingEstimationEnabled = true,
    bool preferNativeGeospatial = true,
    bool preferCloudAnchors = false,
    bool preferDepth = false,
    bool preferOcclusion = false,
    int? targetFrameRate,
  }) {
    return planSession(
      detectHorizontalPlanes: detectHorizontalPlanes,
      detectVerticalPlanes: detectVerticalPlanes,
      lightingEstimationEnabled: lightingEstimationEnabled,
      preferNativeGeospatial: preferNativeGeospatial,
      preferCloudAnchors: preferCloudAnchors,
      preferDepth: preferDepth,
      preferOcclusion: preferOcclusion,
      targetFrameRate: targetFrameRate,
    ).resolution;
  }
}
