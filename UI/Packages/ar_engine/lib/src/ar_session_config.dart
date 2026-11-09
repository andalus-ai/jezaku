/// Configuration for an AR session.
///
/// Pass to [ARWidget] or [ARController.reconfigure].
class ARSessionConfig {
  /// Detect horizontal planes (floors, tables, countertops).
  final bool detectHorizontalPlanes;

  /// Detect vertical planes (walls, doors, whiteboards).
  final bool detectVerticalPlanes;

  /// Estimate ambient light intensity from the camera feed.
  final bool lightingEstimationEnabled;

  /// Enable Google Cloud Anchors (requires network + API key).
  final bool cloudAnchorsEnabled;

  /// Image targets for world-tracking image detection.
  final List<ARImageTarget> imageTargets;

  /// Target frame rate. Null = platform default (~60 fps).
  final int? targetFrameRate;

  /// Show ARCore/ARKit feature points in the debug view.
  final bool showFeaturePoints;

  /// Enable people / environment occlusion.
  ///
  /// Requires ARCore Depth API (Android) or ARKit LiDAR (iOS).
  final bool occlusionEnabled;

  /// Request scene-depth data each frame.
  ///
  /// Activates `ARWorldTrackingConfiguration.frameSemantics.sceneDepth` on iOS
  /// and `Config.DepthMode.AUTOMATIC` on Android.
  final bool depthEnabled;

  /// Enable body / skeleton tracking (iOS ARBodyTrackingConfiguration).
  final bool bodyTrackingEnabled;

  /// Enable native geospatial tracking when the platform supports it.
  ///
  /// Android maps this to ARCore Geospatial Mode. iOS maps this to
  /// `ARGeoTrackingConfiguration` in supported regions/devices. Callers can
  /// still add geospatial anchors without this flag; the Dart fallback projects
  /// latitude/longitude into local AR coordinates.
  final bool geospatialEnabled;

  const ARSessionConfig({
    this.detectHorizontalPlanes = true,
    this.detectVerticalPlanes = false,
    this.lightingEstimationEnabled = true,
    this.cloudAnchorsEnabled = false,
    this.imageTargets = const [],
    this.targetFrameRate,
    this.showFeaturePoints = false,
    this.occlusionEnabled = false,
    this.depthEnabled = false,
    this.bodyTrackingEnabled = false,
    this.geospatialEnabled = false,
  });

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARSessionConfig copyWith({
    bool? detectHorizontalPlanes,
    bool? detectVerticalPlanes,
    bool? lightingEstimationEnabled,
    bool? cloudAnchorsEnabled,
    List<ARImageTarget>? imageTargets,
    int? targetFrameRate,
    bool clearTargetFrameRate = false,
    bool? showFeaturePoints,
    bool? occlusionEnabled,
    bool? depthEnabled,
    bool? bodyTrackingEnabled,
    bool? geospatialEnabled,
  }) {
    assert(
      !clearTargetFrameRate || targetFrameRate == null,
      'Use either targetFrameRate or clearTargetFrameRate.',
    );

    return ARSessionConfig(
      detectHorizontalPlanes:
          detectHorizontalPlanes ?? this.detectHorizontalPlanes,
      detectVerticalPlanes: detectVerticalPlanes ?? this.detectVerticalPlanes,
      lightingEstimationEnabled:
          lightingEstimationEnabled ?? this.lightingEstimationEnabled,
      cloudAnchorsEnabled: cloudAnchorsEnabled ?? this.cloudAnchorsEnabled,
      imageTargets: imageTargets ?? this.imageTargets,
      targetFrameRate:
          clearTargetFrameRate ? null : targetFrameRate ?? this.targetFrameRate,
      showFeaturePoints: showFeaturePoints ?? this.showFeaturePoints,
      occlusionEnabled: occlusionEnabled ?? this.occlusionEnabled,
      depthEnabled: depthEnabled ?? this.depthEnabled,
      bodyTrackingEnabled: bodyTrackingEnabled ?? this.bodyTrackingEnabled,
      geospatialEnabled: geospatialEnabled ?? this.geospatialEnabled,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'detectHorizontalPlanes': detectHorizontalPlanes,
        'detectVerticalPlanes': detectVerticalPlanes,
        'lightingEstimationEnabled': lightingEstimationEnabled,
        'cloudAnchorsEnabled': cloudAnchorsEnabled,
        'imageTargets': imageTargets.map((t) => t.toMap()).toList(),
        'targetFrameRate': targetFrameRate,
        'showFeaturePoints': showFeaturePoints,
        'occlusionEnabled': occlusionEnabled,
        'depthEnabled': depthEnabled,
        'bodyTrackingEnabled': bodyTrackingEnabled,
        'geospatialEnabled': geospatialEnabled,
      };

  factory ARSessionConfig.fromMap(Map<dynamic, dynamic> m) => ARSessionConfig(
        detectHorizontalPlanes: m['detectHorizontalPlanes'] as bool? ?? true,
        detectVerticalPlanes: m['detectVerticalPlanes'] as bool? ?? false,
        lightingEstimationEnabled:
            m['lightingEstimationEnabled'] as bool? ?? true,
        cloudAnchorsEnabled: m['cloudAnchorsEnabled'] as bool? ?? false,
        imageTargets: (m['imageTargets'] as List? ?? [])
            .map((t) => ARImageTarget.fromMap(t as Map))
            .toList(),
        targetFrameRate: m['targetFrameRate'] as int?,
        showFeaturePoints: m['showFeaturePoints'] as bool? ?? false,
        occlusionEnabled: m['occlusionEnabled'] as bool? ?? false,
        depthEnabled: m['depthEnabled'] as bool? ?? false,
        bodyTrackingEnabled: m['bodyTrackingEnabled'] as bool? ?? false,
        geospatialEnabled: m['geospatialEnabled'] as bool? ?? false,
      );

  // ── Object ────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      other is ARSessionConfig &&
      detectHorizontalPlanes == other.detectHorizontalPlanes &&
      detectVerticalPlanes == other.detectVerticalPlanes &&
      lightingEstimationEnabled == other.lightingEstimationEnabled &&
      cloudAnchorsEnabled == other.cloudAnchorsEnabled &&
      _imageTargetListsEqual(imageTargets, other.imageTargets) &&
      showFeaturePoints == other.showFeaturePoints &&
      occlusionEnabled == other.occlusionEnabled &&
      depthEnabled == other.depthEnabled &&
      bodyTrackingEnabled == other.bodyTrackingEnabled &&
      geospatialEnabled == other.geospatialEnabled &&
      targetFrameRate == other.targetFrameRate;

  @override
  int get hashCode => Object.hash(
        detectHorizontalPlanes,
        detectVerticalPlanes,
        lightingEstimationEnabled,
        cloudAnchorsEnabled,
        _imageTargetListHash(imageTargets),
        showFeaturePoints,
        occlusionEnabled,
        depthEnabled,
        bodyTrackingEnabled,
        geospatialEnabled,
        targetFrameRate,
      );

  @override
  String toString() =>
      'ARSessionConfig(H:$detectHorizontalPlanes V:$detectVerticalPlanes '
      'light:$lightingEstimationEnabled occ:$occlusionEnabled '
      'depth:$depthEnabled geo:$geospatialEnabled fps:$targetFrameRate)';
}

bool _imageTargetListsEqual(
  List<ARImageTarget> left,
  List<ARImageTarget> right,
) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    final a = left[i];
    final b = right[i];
    if (a.name != b.name ||
        a.assetPath != b.assetPath ||
        a.physicalWidthMeters != b.physicalWidthMeters) {
      return false;
    }
  }
  return true;
}

int _imageTargetListHash(List<ARImageTarget> targets) => Object.hashAll(
      targets.map(
        (target) => Object.hash(
          target.name,
          target.assetPath,
          target.physicalWidthMeters,
        ),
      ),
    );

// ─── ARImageTarget ────────────────────────────────────────────────────────────

/// An image that ARCore/ARKit should recognise and track in the environment.
class ARImageTarget {
  final String name;
  final String assetPath;

  /// Physical width in metres. Required for ARKit, helpful for ARCore.
  final double physicalWidthMeters;

  const ARImageTarget({
    required this.name,
    required this.assetPath,
    required this.physicalWidthMeters,
  });

  ARImageTarget copyWith({
    String? name,
    String? assetPath,
    double? physicalWidthMeters,
  }) =>
      ARImageTarget(
        name: name ?? this.name,
        assetPath: assetPath ?? this.assetPath,
        physicalWidthMeters: physicalWidthMeters ?? this.physicalWidthMeters,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'assetPath': assetPath,
        'physicalWidthMeters': physicalWidthMeters,
      };

  factory ARImageTarget.fromMap(Map<dynamic, dynamic> m) => ARImageTarget(
        name: m['name'] as String,
        assetPath: m['assetPath'] as String,
        physicalWidthMeters: (m['physicalWidthMeters'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is ARImageTarget &&
      name == other.name &&
      assetPath == other.assetPath;

  @override
  int get hashCode => Object.hash(name, assetPath);

  @override
  String toString() => 'ARImageTarget($name, width: ${physicalWidthMeters}m)';
}
