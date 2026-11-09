import 'package:ar_engine/ar_engine.dart';

/// Named looks for hanging photo frames used by Jejaku memory nodes.
enum JejakuHangingPhotoFramePreset {
  /// Warm, dimensional frame that matches the original default.
  classic,

  /// Minimal trim for photos that should feel lightweight in AR.
  thin,

  /// Dark matte frame suited for gallery-style placements.
  darkGallery,

  /// Slim translucent frame for floating glass-style memories.
  floatingGlass,
}

/// Builds the 3D child-node structure for a hanging photo memory frame.
class JejakuHangingPhotoFrameStyle {
  const JejakuHangingPhotoFrameStyle({
    this.preset = JejakuHangingPhotoFramePreset.classic,
    this.borderMeters = 0.072,
    this.depthMeters = 0.10,
    this.photoRecessMeters,
    this.backingThicknessMeters,
    this.topLipHeightMeters = 0.008,
    this.frameMaterial = const ARMaterial(
      baseColor: ARMaterialColor(r: 0.055, g: 0.046, b: 0.036),
      roughness: 0.55,
      doubleSided: true,
    ),
    this.backingMaterial = const ARMaterial(
      baseColor: ARMaterialColor(r: 0.035, g: 0.032, b: 0.028),
      roughness: 0.72,
    ),
    this.highlightMaterial = const ARMaterial(
      baseColor: ARMaterialColor(r: 0.12, g: 0.095, b: 0.064),
      roughness: 0.48,
    ),
  });

  const JejakuHangingPhotoFrameStyle.classic()
      : this(preset: JejakuHangingPhotoFramePreset.classic);

  const JejakuHangingPhotoFrameStyle.thin()
      : this(
          preset: JejakuHangingPhotoFramePreset.thin,
          borderMeters: 0.042,
          depthMeters: 0.065,
          topLipHeightMeters: 0.004,
          frameMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.135, g: 0.12, b: 0.105),
            roughness: 0.62,
            doubleSided: true,
          ),
          backingMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.045, g: 0.042, b: 0.038),
            roughness: 0.76,
          ),
          highlightMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.22, g: 0.19, b: 0.15),
            roughness: 0.58,
          ),
        );

  const JejakuHangingPhotoFrameStyle.darkGallery()
      : this(
          preset: JejakuHangingPhotoFramePreset.darkGallery,
          borderMeters: 0.08,
          depthMeters: 0.085,
          topLipHeightMeters: 0.006,
          frameMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.012, g: 0.012, b: 0.014),
            roughness: 0.84,
            doubleSided: true,
          ),
          backingMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.006, g: 0.006, b: 0.007),
            roughness: 0.9,
          ),
          highlightMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.055, g: 0.055, b: 0.06),
            roughness: 0.72,
          ),
        );

  const JejakuHangingPhotoFrameStyle.floatingGlass()
      : this(
          preset: JejakuHangingPhotoFramePreset.floatingGlass,
          borderMeters: 0.035,
          depthMeters: 0.045,
          topLipHeightMeters: 0.003,
          frameMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.82, g: 0.92, b: 1),
            roughness: 0.08,
            opacity: 0.32,
            doubleSided: true,
            blendMode: ARBlendMode.alpha,
          ),
          backingMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.72, g: 0.86, b: 0.95),
            roughness: 0.16,
            opacity: 0.18,
            doubleSided: true,
            blendMode: ARBlendMode.alpha,
          ),
          highlightMaterial: const ARMaterial(
            baseColor: ARMaterialColor(r: 0.95, g: 0.98, b: 1),
            roughness: 0.04,
            opacity: 0.46,
            doubleSided: true,
            blendMode: ARBlendMode.alpha,
          ),
        );

  static const classicPreset = JejakuHangingPhotoFrameStyle.classic();
  static const thinPreset = JejakuHangingPhotoFrameStyle.thin();
  static const darkGalleryPreset = JejakuHangingPhotoFrameStyle.darkGallery();
  static const floatingGlassPreset =
      JejakuHangingPhotoFrameStyle.floatingGlass();

  static JejakuHangingPhotoFrameStyle fromPreset(
    JejakuHangingPhotoFramePreset preset,
  ) {
    return switch (preset) {
      JejakuHangingPhotoFramePreset.classic => classicPreset,
      JejakuHangingPhotoFramePreset.thin => thinPreset,
      JejakuHangingPhotoFramePreset.darkGallery => darkGalleryPreset,
      JejakuHangingPhotoFramePreset.floatingGlass => floatingGlassPreset,
    };
  }

  factory JejakuHangingPhotoFrameStyle.fromMetadata(
    Map<String, Object?> metadata, {
    JejakuHangingPhotoFrameStyle fallback =
        const JejakuHangingPhotoFrameStyle(),
  }) {
    final style = _map(metadata['photoFrameStyle']);
    final namedPreset =
        _preset(style?['preset'] ?? metadata['photoFramePreset']);
    final baseStyle = namedPreset == null
        ? fallback
        : JejakuHangingPhotoFrameStyle.fromPreset(namedPreset);
    return JejakuHangingPhotoFrameStyle(
      preset: baseStyle.preset,
      borderMeters: _clampedPositive(
        style?['borderMeters'] ?? metadata['frameBorderMeters'],
        fallback: baseStyle.borderMeters,
        min: 0.02,
        max: 0.18,
      ),
      depthMeters: _clampedPositive(
        style?['depthMeters'] ?? metadata['frameDepthMeters'],
        fallback: baseStyle.depthMeters,
        min: 0.025,
        max: 0.24,
      ),
      photoRecessMeters: _positive(
            style?['photoRecessMeters'] ?? metadata['photoRecessMeters'],
          ) ??
          baseStyle.photoRecessMeters,
      backingThicknessMeters: _positive(
            style?['backingThicknessMeters'] ??
                metadata['frameBackingThicknessMeters'],
          ) ??
          baseStyle.backingThicknessMeters,
      topLipHeightMeters: _clampedPositive(
        style?['topLipHeightMeters'] ?? metadata['frameTopLipHeightMeters'],
        fallback: baseStyle.topLipHeightMeters,
        min: 0.002,
        max: 0.04,
      ),
      frameMaterial:
          _material(style?['frameMaterial']) ?? baseStyle.frameMaterial,
      backingMaterial:
          _material(style?['backingMaterial']) ?? baseStyle.backingMaterial,
      highlightMaterial:
          _material(style?['highlightMaterial']) ?? baseStyle.highlightMaterial,
    );
  }

  final JejakuHangingPhotoFramePreset preset;
  final double borderMeters;
  final double depthMeters;
  final double? photoRecessMeters;
  final double? backingThicknessMeters;
  final double topLipHeightMeters;
  final ARMaterial frameMaterial;
  final ARMaterial backingMaterial;
  final ARMaterial highlightMaterial;

  double get effectivePhotoRecessMeters {
    final recess = photoRecessMeters ?? depthMeters * 0.46;
    return recess.clamp(0.008, depthMeters * 0.72).toDouble();
  }

  double get effectiveBackingThicknessMeters {
    final thickness = backingThicknessMeters ?? depthMeters * 0.18;
    return thickness.clamp(0.004, depthMeters * 0.36).toDouble();
  }

  ARVector3 outerSizeFor(ARVector3 photoSizeMeters) {
    return ARVector3(
      photoSizeMeters.x + borderMeters * 2,
      depthMeters,
      photoSizeMeters.z + borderMeters * 2,
    );
  }

  Map<String, Object?> toMetadata(ARVector3 photoSizeMeters) {
    final outerSize = outerSizeFor(photoSizeMeters);
    return <String, Object?>{
      'kind': 'hanging_3d_photo_frame',
      'preset': preset.name,
      'photoSizeMeters': photoSizeMeters.toMap(),
      'outerSizeMeters': outerSize.toMap(),
      'borderMeters': borderMeters,
      'depthMeters': depthMeters,
      'photoRecessMeters': effectivePhotoRecessMeters,
      'backingThicknessMeters': effectiveBackingThicknessMeters,
      'topLipHeightMeters': topLipHeightMeters,
    };
  }

  ARNode buildNode({
    required String id,
    required ARVector3 photoSizeMeters,
    required ARVector3 position,
    required ARQuaternion rotation,
    required ARMaterial photoMaterial,
    required Map<String, Object?> metadata,
  }) {
    final children = buildChildren(id: id, photoSizeMeters: photoSizeMeters);
    return ARNode(
      id: id,
      position: position,
      primitiveShape: ARPrimitiveShape.plane,
      primitiveSize: photoSizeMeters,
      rotation: rotation,
      scale: const ARVector3.one(),
      material: photoMaterial,
      children: children,
      metadata: <String, Object?>{
        ...metadata,
        'photoFrame': true,
        'photoFrameKind': 'hanging_3d_photo_frame',
        'photoFramePreset': preset.name,
        'photoFrameStyle': toMetadata(photoSizeMeters),
        'photoFrameChildNodeIds': [
          for (final child in children) child.id,
        ],
        'frameBorderMeters': borderMeters,
        'frameDepthMeters': depthMeters,
        'photoRecessMeters': effectivePhotoRecessMeters,
        'frameBackingThicknessMeters': effectiveBackingThicknessMeters,
        'frameTopLipHeightMeters': topLipHeightMeters,
        'photoFrameOuterSizeMeters': outerSizeFor(photoSizeMeters).toMap(),
      },
    );
  }

  List<ARNode> buildChildren({
    required String id,
    required ARVector3 photoSizeMeters,
  }) {
    final outerWidth = photoSizeMeters.x + borderMeters * 2;
    final outerHeight = photoSizeMeters.z + borderMeters * 2;
    final backingThickness = effectiveBackingThicknessMeters;
    final topLipDepth = borderMeters * 0.18;
    return <ARNode>[
      _part(
        id: '${id}_frame_backing',
        role: 'backing',
        position: ARVector3(0, -depthMeters / 2 + backingThickness / 2, 0),
        size: ARVector3(outerWidth, backingThickness, outerHeight),
        material: backingMaterial,
      ),
      _part(
        id: '${id}_frame_top',
        role: 'topRail',
        position: ARVector3(0, 0, photoSizeMeters.z / 2 + borderMeters / 2),
        size: ARVector3(outerWidth, depthMeters, borderMeters),
        material: frameMaterial,
      ),
      _part(
        id: '${id}_frame_bottom',
        role: 'bottomRail',
        position: ARVector3(0, 0, -photoSizeMeters.z / 2 - borderMeters / 2),
        size: ARVector3(outerWidth, depthMeters, borderMeters),
        material: frameMaterial,
      ),
      _part(
        id: '${id}_frame_left',
        role: 'leftRail',
        position: ARVector3(-photoSizeMeters.x / 2 - borderMeters / 2, 0, 0),
        size: ARVector3(borderMeters, depthMeters, photoSizeMeters.z),
        material: frameMaterial,
      ),
      _part(
        id: '${id}_frame_right',
        role: 'rightRail',
        position: ARVector3(photoSizeMeters.x / 2 + borderMeters / 2, 0, 0),
        size: ARVector3(borderMeters, depthMeters, photoSizeMeters.z),
        material: frameMaterial,
      ),
      _part(
        id: '${id}_frame_top_lip',
        role: 'topHighlightLip',
        position: ARVector3(
          0,
          depthMeters / 2 + topLipHeightMeters / 2,
          photoSizeMeters.z / 2 + borderMeters * 0.78,
        ),
        size: ARVector3(outerWidth * 0.92, topLipHeightMeters, topLipDepth),
        material: highlightMaterial,
      ),
    ];
  }

  static ARNode _part({
    required String id,
    required String role,
    required ARVector3 position,
    required ARVector3 size,
    required ARMaterial material,
  }) {
    return ARNode(
      id: id,
      position: position,
      primitiveShape: ARPrimitiveShape.cube,
      primitiveSize: size,
      material: material,
      metadata: <String, Object?>{
        'package': 'jezaku_ar',
        'kind': 'hanging_photo_frame_part',
        'photoFramePart': role,
      },
    );
  }

  static Map<dynamic, dynamic>? _map(Object? value) {
    return value is Map ? value : null;
  }

  static ARMaterial? _material(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARMaterial.fromMap(value);
    } on Object {
      return null;
    }
  }

  static double? _positive(Object? value) {
    final number = _number(value);
    if (number == null || number <= 0) {
      return null;
    }
    return number;
  }

  static double _clampedPositive(
    Object? value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    final number = _positive(value) ?? fallback;
    return number.clamp(min, max).toDouble();
  }

  static JejakuHangingPhotoFramePreset? _preset(Object? value) {
    if (value is JejakuHangingPhotoFramePreset) {
      return value;
    }
    if (value is! String) {
      return null;
    }
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return switch (normalized) {
      'classic' => JejakuHangingPhotoFramePreset.classic,
      'thin' => JejakuHangingPhotoFramePreset.thin,
      'darkgallery' => JejakuHangingPhotoFramePreset.darkGallery,
      'gallerydark' => JejakuHangingPhotoFramePreset.darkGallery,
      'floatingglass' => JejakuHangingPhotoFramePreset.floatingGlass,
      'glass' => JejakuHangingPhotoFramePreset.floatingGlass,
      _ => null,
    };
  }

  static double? _number(Object? value) {
    if (value is num) {
      final number = value.toDouble();
      return number.isFinite ? number : null;
    }
    if (value is String && value.trim().isNotEmpty) {
      final number = double.tryParse(value);
      return number != null && number.isFinite ? number : null;
    }
    return null;
  }
}
