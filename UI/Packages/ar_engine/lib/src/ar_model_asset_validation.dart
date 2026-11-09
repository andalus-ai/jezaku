import 'ar_model_asset.dart';
import 'models/ar_vector3.dart';

enum ARModelAssetValidationTarget { descriptor, android, ios, crossPlatform }

enum ARModelAssetValidationSeverity { warning, error }

enum ARModelAssetRenderPlatform { android, ios }

enum ARModelAssetRenderMode {
  nativeMesh,
  primitiveFallback,
  requiresPreparation,
}

enum ARModelAssetValidationIssueCode {
  customFormat,
  missingFallbackSize,
  invalidFallbackSize,
  androidPrimitiveFallback,
  iosSceneKitCompatibility,
  networkSourceRequiresLoader,
  packageIgnoredForSource,
  fileUrlPath,
}

class ARModelAssetValidationIssue {
  const ARModelAssetValidationIssue({
    required this.code,
    required this.severity,
    required this.label,
  });

  final ARModelAssetValidationIssueCode code;
  final ARModelAssetValidationSeverity severity;
  final String label;

  bool get isError => severity == ARModelAssetValidationSeverity.error;

  bool get isWarning => severity == ARModelAssetValidationSeverity.warning;
}

class ARModelAssetPlatformRenderProfile {
  const ARModelAssetPlatformRenderProfile({
    required this.platform,
    required this.mode,
    required this.label,
    this.notes = const <String>[],
  });

  final ARModelAssetRenderPlatform platform;
  final ARModelAssetRenderMode mode;
  final String label;
  final List<String> notes;

  bool get rendersModelMesh => mode == ARModelAssetRenderMode.nativeMesh;

  bool get usesPrimitiveFallback =>
      mode == ARModelAssetRenderMode.primitiveFallback;

  bool get requiresPreparation =>
      mode == ARModelAssetRenderMode.requiresPreparation;

  Map<String, Object?> toMap() => <String, Object?>{
        'platform': platform.name,
        'mode': mode.name,
        'label': label,
        'notes': notes,
      };
}

class ARModelAssetRenderProfile {
  const ARModelAssetRenderProfile({
    required this.asset,
    required this.android,
    required this.ios,
  });

  factory ARModelAssetRenderProfile.forAsset(ARModelAsset asset) =>
      ARModelAssetRenderProfile(
        asset: asset,
        android: _androidRenderProfile(asset),
        ios: _iosRenderProfile(asset),
      );

  final ARModelAsset asset;
  final ARModelAssetPlatformRenderProfile android;
  final ARModelAssetPlatformRenderProfile ios;

  List<ARModelAssetPlatformRenderProfile> get platforms => [android, ios];

  List<String> get platformLabels => [
        for (final profile in platforms) profile.label,
      ];

  List<String> get noteLabels {
    final labels = <String>{};
    for (final profile in platforms) {
      labels.addAll(profile.notes);
    }
    return List<String>.unmodifiable(labels);
  }

  bool get rendersModelMeshEverywhere =>
      platforms.every((profile) => profile.rendersModelMesh);

  bool get usesAnyPrimitiveFallback =>
      platforms.any((profile) => profile.usesPrimitiveFallback);

  bool get requiresPreparation =>
      platforms.any((profile) => profile.requiresPreparation);

  String get summaryLabel {
    if (rendersModelMeshEverywhere) {
      return 'Native mesh on Android and iOS';
    }
    return platformLabels.join('; ');
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'summaryLabel': summaryLabel,
        'usesAnyPrimitiveFallback': usesAnyPrimitiveFallback,
        'requiresPreparation': requiresPreparation,
        'platforms': [
          for (final profile in platforms) profile.toMap(),
        ],
        'notes': noteLabels,
      };
}

class ARModelAssetValidationReport {
  const ARModelAssetValidationReport({
    required this.asset,
    required this.target,
    required this.issues,
  });

  final ARModelAsset asset;
  final ARModelAssetValidationTarget target;
  final List<ARModelAssetValidationIssue> issues;

  bool get isValid => !issues.any((issue) => issue.isError);

  bool get hasWarnings => issues.any((issue) => issue.isWarning);

  List<ARModelAssetValidationIssue> get errors => [
        for (final issue in issues)
          if (issue.isError) issue,
      ];

  List<ARModelAssetValidationIssue> get warnings => [
        for (final issue in issues)
          if (issue.isWarning) issue,
      ];

  List<String> get issueLabels => [
        for (final issue in issues) issue.label,
      ];

  List<String> get errorLabels => [
        for (final issue in errors) issue.label,
      ];

  List<String> get warningLabels => [
        for (final issue in warnings) issue.label,
      ];

  bool get usesAndroidPrimitiveFallback => issues.any(
        (issue) =>
            issue.code ==
            ARModelAssetValidationIssueCode.androidPrimitiveFallback,
      );

  ARModelAssetRenderProfile get renderProfile => asset.renderProfile();

  String get summaryLabel {
    final errorCount = errors.length;
    if (errorCount > 0) {
      final label = errorCount == 1 ? 'issue' : 'issues';
      return 'Model asset has $errorCount blocking $label';
    }
    final warningCount = warnings.length;
    if (warningCount > 0) {
      final label = warningCount == 1 ? 'warning' : 'warnings';
      return 'Model asset ready with $warningCount $label';
    }
    return 'Model asset ready';
  }
}

extension ARModelAssetValidation on ARModelAsset {
  ARModelAssetRenderProfile renderProfile() =>
      ARModelAssetRenderProfile.forAsset(this);

  ARModelAssetValidationReport validate({
    ARModelAssetValidationTarget target =
        ARModelAssetValidationTarget.crossPlatform,
  }) {
    final issues = <ARModelAssetValidationIssue>[];

    void add(
      ARModelAssetValidationIssueCode code,
      ARModelAssetValidationSeverity severity,
      String label,
    ) {
      issues.add(
        ARModelAssetValidationIssue(
          code: code,
          severity: severity,
          label: label,
        ),
      );
    }

    if (format == ARModelFormat.custom) {
      add(
        ARModelAssetValidationIssueCode.customFormat,
        ARModelAssetValidationSeverity.warning,
        'Model format could not be inferred; set a supported format explicitly.',
      );
    }

    final fallback = fallbackSizeMeters;
    if (fallback == null) {
      add(
        ARModelAssetValidationIssueCode.missingFallbackSize,
        ARModelAssetValidationSeverity.warning,
        'No fallback size supplied; primitive fallback uses the node scale.',
      );
    } else if (!_isPositiveFiniteVector(fallback)) {
      add(
        ARModelAssetValidationIssueCode.invalidFallbackSize,
        ARModelAssetValidationSeverity.error,
        'Fallback size must use finite positive dimensions.',
      );
    }

    if (source == ARModelAssetSource.network && _checksAndroid(target)) {
      add(
        ARModelAssetValidationIssueCode.networkSourceRequiresLoader,
        ARModelAssetValidationSeverity.warning,
        'Network models require app-level download/cache before Android rendering.',
      );
    }

    if (source == ARModelAssetSource.file && path.startsWith('file://')) {
      add(
        ARModelAssetValidationIssueCode.fileUrlPath,
        ARModelAssetValidationSeverity.warning,
        'File model paths should be absolute paths without a file:// prefix.',
      );
    }

    if (package != null && source != ARModelAssetSource.flutterAsset) {
      add(
        ARModelAssetValidationIssueCode.packageIgnoredForSource,
        ARModelAssetValidationSeverity.warning,
        'Package is only used for Flutter asset model sources.',
      );
    }

    if (_checksAndroid(target) &&
        format != ARModelFormat.obj &&
        format != ARModelFormat.custom) {
      add(
        ARModelAssetValidationIssueCode.androidPrimitiveFallback,
        ARModelAssetValidationSeverity.warning,
        'Android imports OBJ meshes directly; this format uses primitive fallback rendering.',
      );
    }

    if (_checksIos(target) && !_iosSceneKitPreferredFormats.contains(format)) {
      add(
        ARModelAssetValidationIssueCode.iosSceneKitCompatibility,
        ARModelAssetValidationSeverity.warning,
        'iOS SceneKit loading may require conversion for this model format.',
      );
    }

    return ARModelAssetValidationReport(
      asset: this,
      target: target,
      issues: List<ARModelAssetValidationIssue>.unmodifiable(issues),
    );
  }
}

const _iosSceneKitPreferredFormats = <ARModelFormat>{
  ARModelFormat.obj,
  ARModelFormat.scn,
  ARModelFormat.usdz,
  ARModelFormat.reality,
};

ARModelAssetPlatformRenderProfile _androidRenderProfile(ARModelAsset asset) {
  if (asset.source == ARModelAssetSource.network) {
    return ARModelAssetPlatformRenderProfile(
      platform: ARModelAssetRenderPlatform.android,
      mode: ARModelAssetRenderMode.requiresPreparation,
      label: 'Android cache preparation required',
      notes: <String>[
        'Network models must be cached before Android rendering.',
        if (asset.format != ARModelFormat.obj)
          'Convert to OBJ for Android native mesh rendering.',
      ],
    );
  }
  if (asset.format == ARModelFormat.obj) {
    return const ARModelAssetPlatformRenderProfile(
      platform: ARModelAssetRenderPlatform.android,
      mode: ARModelAssetRenderMode.nativeMesh,
      label: 'Android native OBJ mesh',
    );
  }
  if (asset.format == ARModelFormat.custom) {
    return const ARModelAssetPlatformRenderProfile(
      platform: ARModelAssetRenderPlatform.android,
      mode: ARModelAssetRenderMode.requiresPreparation,
      label: 'Android model format required',
      notes: <String>[
        'Set a supported model format before Android rendering.',
      ],
    );
  }
  return const ARModelAssetPlatformRenderProfile(
    platform: ARModelAssetRenderPlatform.android,
    mode: ARModelAssetRenderMode.primitiveFallback,
    label: 'Android primitive fallback',
    notes: <String>[
      'Convert to OBJ for Android native mesh rendering.',
    ],
  );
}

ARModelAssetPlatformRenderProfile _iosRenderProfile(ARModelAsset asset) {
  if (_iosSceneKitPreferredFormats.contains(asset.format)) {
    return const ARModelAssetPlatformRenderProfile(
      platform: ARModelAssetRenderPlatform.ios,
      mode: ARModelAssetRenderMode.nativeMesh,
      label: 'iOS native SceneKit mesh',
    );
  }
  if (asset.format == ARModelFormat.custom) {
    return const ARModelAssetPlatformRenderProfile(
      platform: ARModelAssetRenderPlatform.ios,
      mode: ARModelAssetRenderMode.requiresPreparation,
      label: 'iOS model format required',
      notes: <String>[
        'Set a SceneKit-compatible format before iOS rendering.',
      ],
    );
  }
  return const ARModelAssetPlatformRenderProfile(
    platform: ARModelAssetRenderPlatform.ios,
    mode: ARModelAssetRenderMode.requiresPreparation,
    label: 'iOS model conversion recommended',
    notes: <String>[
      'Convert to OBJ, SCN, USDZ, or Reality for iOS SceneKit loading.',
    ],
  );
}

bool _checksAndroid(ARModelAssetValidationTarget target) =>
    target == ARModelAssetValidationTarget.android ||
    target == ARModelAssetValidationTarget.crossPlatform;

bool _checksIos(ARModelAssetValidationTarget target) =>
    target == ARModelAssetValidationTarget.ios ||
    target == ARModelAssetValidationTarget.crossPlatform;

bool _isPositiveFiniteVector(ARVector3 vector) =>
    _isPositiveFinite(vector.x) &&
    _isPositiveFinite(vector.y) &&
    _isPositiveFinite(vector.z);

bool _isPositiveFinite(double value) => value.isFinite && value > 0;
