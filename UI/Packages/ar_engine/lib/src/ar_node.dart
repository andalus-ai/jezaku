import 'ar_model_asset.dart';
import 'models/ar_vector3.dart';
import 'models/ar_quaternion.dart';

/// The type of 3D content attached to a node.
enum ARNodeContentType { gltf, glb, obj, usdz, scn, reality, primitive, custom }

/// Primitive shape options.
enum ARPrimitiveShape { cube, sphere, cylinder, plane, capsule, torus, cone }

/// Blend mode for transparent materials.
enum ARBlendMode { opaque, alpha, additive, multiply }

// ─── ARNode ───────────────────────────────────────────────────────────────────

/// An immutable node in the AR scene graph.
///
/// Holds transform (position / rotation / scale), optional 3-D content, and
/// a PBR [ARMaterial]. Use [copyWith] to produce modified versions.
class ARNode {
  final String id;
  final ARVector3 position;
  final ARQuaternion rotation;
  final ARVector3 scale;

  final ARNodeContentType contentType;

  /// Asset path for GLTF / GLB / OBJ models. Null for primitives.
  final String? modelPath;

  /// Typed model asset descriptor for model-backed nodes.
  final ARModelAsset? modelAsset;

  /// Primitive shape (ignored when [contentType] is not [ARNodeContentType.primitive]).
  final ARPrimitiveShape? primitiveShape;

  /// Explicit size in metres for primitives. Defaults to [scale] when null.
  final ARVector3? primitiveSize;

  /// PBR material applied to this node.
  final ARMaterial? material;

  /// Child nodes in local space.
  final List<ARNode> children;

  /// Whether this node contributes to shadow maps.
  final bool castsShadow;

  /// Whether this node receives shadows from other nodes.
  final bool receivesShadow;

  /// When false the node exists in the scene graph but is not rendered.
  final bool isVisible;

  /// Draw order for transparent objects. Higher values render last (on top).
  final int renderOrder;

  /// Arbitrary user metadata (not serialised to native beyond toMap).
  final Map<String, dynamic> metadata;

  const ARNode({
    required this.id,
    this.position = const ARVector3.zero(),
    this.rotation = const ARQuaternion.identity(),
    this.scale = const ARVector3.one(),
    this.contentType = ARNodeContentType.primitive,
    this.modelPath,
    this.modelAsset,
    this.primitiveShape = ARPrimitiveShape.cube,
    this.primitiveSize,
    this.material,
    this.children = const [],
    this.castsShadow = true,
    this.receivesShadow = true,
    this.isVisible = true,
    this.renderOrder = 0,
    this.metadata = const {},
  });

  factory ARNode.model({
    required String id,
    required ARModelAsset asset,
    ARVector3 position = const ARVector3.zero(),
    ARQuaternion rotation = const ARQuaternion.identity(),
    ARVector3 scale = const ARVector3.one(),
    ARMaterial? material,
    List<ARNode> children = const <ARNode>[],
    bool castsShadow = true,
    bool receivesShadow = true,
    bool isVisible = true,
    int renderOrder = 0,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return ARNode(
      id: id,
      position: position,
      rotation: rotation,
      scale: scale,
      contentType: _contentTypeForModelAsset(asset) ?? ARNodeContentType.custom,
      modelPath: asset.path,
      modelAsset: asset,
      primitiveShape: ARPrimitiveShape.cube,
      primitiveSize: asset.fallbackSizeMeters,
      material: material,
      children: children,
      castsShadow: castsShadow,
      receivesShadow: receivesShadow,
      isVisible: isVisible,
      renderOrder: renderOrder,
      metadata: metadata,
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARNode copyWith({
    String? id,
    ARVector3? position,
    ARQuaternion? rotation,
    ARVector3? scale,
    ARMaterial? material,
    String? modelPath,
    ARModelAsset? modelAsset,
    ARNodeContentType? contentType,
    ARPrimitiveShape? primitiveShape,
    ARVector3? primitiveSize,
    List<ARNode>? children,
    bool? castsShadow,
    bool? receivesShadow,
    bool? isVisible,
    int? renderOrder,
    Map<String, dynamic>? metadata,
  }) =>
      ARNode(
        id: id ?? this.id,
        position: position ?? this.position,
        rotation: rotation ?? this.rotation,
        scale: scale ?? this.scale,
        contentType: contentType ??
            _contentTypeForModelAsset(modelAsset ?? this.modelAsset) ??
            this.contentType,
        modelPath: modelPath ?? modelAsset?.path ?? this.modelPath,
        modelAsset: modelAsset ?? this.modelAsset,
        primitiveShape: primitiveShape ?? this.primitiveShape,
        primitiveSize: primitiveSize ?? this.primitiveSize,
        material: material ?? this.material,
        children: children ?? this.children,
        castsShadow: castsShadow ?? this.castsShadow,
        receivesShadow: receivesShadow ?? this.receivesShadow,
        isVisible: isVisible ?? this.isVisible,
        renderOrder: renderOrder ?? this.renderOrder,
        metadata: metadata ?? this.metadata,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'position': position.toMap(),
        'rotation': rotation.toMap(),
        'scale': scale.toMap(),
        'contentType': contentType.name,
        'modelPath': effectiveModelAsset?.path ?? modelPath,
        'modelAsset': effectiveModelAsset?.toMap(),
        'primitiveShape': primitiveShape?.name,
        'primitiveSize': primitiveSize?.toMap(),
        'material': material?.toMap(),
        'children': children.map((c) => c.toMap()).toList(),
        'castsShadow': castsShadow,
        'receivesShadow': receivesShadow,
        'isVisible': isVisible,
        'renderOrder': renderOrder,
        'metadata': metadata,
      };

  factory ARNode.fromMap(Map<dynamic, dynamic> map) {
    final modelAsset = ARModelAsset.tryFromMap(map['modelAsset']);
    final legacyModelAsset = modelAsset == null
        ? _legacyModelAsset(
            map['modelPath'],
            ARNodeContentType.custom,
            map['primitiveSize'],
          )
        : null;
    final contentType = ARNodeContentType.values.firstWhere(
      (e) => e.name == map['contentType'],
      orElse: () =>
          _contentTypeForModelAsset(modelAsset ?? legacyModelAsset) ??
          ARNodeContentType.primitive,
    );
    return ARNode(
      id: map['id'] as String,
      position: ARVector3.fromMap(map['position'] as Map),
      rotation: ARQuaternion.fromMap(map['rotation'] as Map),
      scale: ARVector3.fromMap(map['scale'] as Map),
      contentType: contentType,
      modelPath: (modelAsset ?? legacyModelAsset)?.path ??
          (map['modelPath'] as String?),
      modelAsset: modelAsset ?? legacyModelAsset,
      primitiveShape: map['primitiveShape'] != null
          ? ARPrimitiveShape.values.firstWhere(
              (e) => e.name == map['primitiveShape'],
              orElse: () => ARPrimitiveShape.cube)
          : null,
      primitiveSize: map['primitiveSize'] != null
          ? ARVector3.fromMap(map['primitiveSize'] as Map)
          : null,
      material: map['material'] != null
          ? ARMaterial.fromMap(map['material'] as Map)
          : null,
      children: (map['children'] as List? ?? [])
          .map((c) => ARNode.fromMap(c as Map))
          .toList(),
      castsShadow: map['castsShadow'] as bool? ?? true,
      receivesShadow: map['receivesShadow'] as bool? ?? true,
      isVisible: map['isVisible'] as bool? ?? true,
      renderOrder: map['renderOrder'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  ARModelAsset? get effectiveModelAsset =>
      modelAsset ??
      _legacyModelAsset(modelPath, contentType, primitiveSize?.toMap());

  bool get isModelNode => effectiveModelAsset != null;

  @override
  String toString() =>
      'ARNode(id: $id, shape: $primitiveShape, pos: $position)';

  @override
  bool operator ==(Object other) => other is ARNode && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

ARNodeContentType? _contentTypeForModelAsset(ARModelAsset? asset) {
  if (asset == null) {
    return null;
  }
  return switch (asset.format) {
    ARModelFormat.glb => ARNodeContentType.glb,
    ARModelFormat.gltf => ARNodeContentType.gltf,
    ARModelFormat.obj => ARNodeContentType.obj,
    ARModelFormat.usdz => ARNodeContentType.usdz,
    ARModelFormat.scn => ARNodeContentType.scn,
    ARModelFormat.reality => ARNodeContentType.reality,
    ARModelFormat.custom => ARNodeContentType.custom,
  };
}

ARModelAsset? _legacyModelAsset(
  Object? modelPath,
  ARNodeContentType contentType,
  Object? fallbackSizeMeters,
) {
  if (modelPath is! String || modelPath.trim().isEmpty) {
    return null;
  }
  final format = switch (contentType) {
    ARNodeContentType.glb => ARModelFormat.glb,
    ARNodeContentType.gltf => ARModelFormat.gltf,
    ARNodeContentType.obj => ARModelFormat.obj,
    ARNodeContentType.usdz => ARModelFormat.usdz,
    ARNodeContentType.scn => ARModelFormat.scn,
    ARNodeContentType.reality => ARModelFormat.reality,
    ARNodeContentType.custom => ARModelAsset.inferFormat(modelPath),
    ARNodeContentType.primitive => ARModelAsset.inferFormat(modelPath),
  };
  return ARModelAsset.fromPath(
    modelPath,
    format: format,
    fallbackSizeMeters: fallbackSizeMeters is Map
        ? ARVector3.fromMap(fallbackSizeMeters)
        : null,
  );
}

// ─── ARMaterial ───────────────────────────────────────────────────────────────

/// Physically-based rendering material.
///
/// Supports the full glTF 2.0 PBR metallic-roughness workflow plus
/// emission, opacity/transparency, double-sided rendering, and
/// all four standard texture channels.
class ARMaterial {
  final ARMaterialColor baseColor;
  final double metallic; // 0–1
  final double roughness; // 0–1
  final double ambientOcclusion; // 0–1 (1 = no occlusion)
  final double? emissiveIntensity;
  final ARMaterialColor? emissiveColor;
  final double opacity; // 0–1
  final bool doubleSided;
  final ARBlendMode blendMode;

  // Texture asset paths (relative to Flutter assets).
  final String? baseColorTexturePath;
  final String? normalMapPath;
  final String? roughnessMapPath;
  final String? metallicMapPath;
  final String? occlusionMapPath;
  final String? emissiveMapPath;

  const ARMaterial({
    this.baseColor = const ARMaterialColor(r: 1, g: 1, b: 1),
    this.metallic = 0.0,
    this.roughness = 0.5,
    this.ambientOcclusion = 1.0,
    this.emissiveIntensity,
    this.emissiveColor,
    this.opacity = 1.0,
    this.doubleSided = false,
    this.blendMode = ARBlendMode.opaque,
    this.baseColorTexturePath,
    this.normalMapPath,
    this.roughnessMapPath,
    this.metallicMapPath,
    this.occlusionMapPath,
    this.emissiveMapPath,
  });

  // ── Convenience constructors ───────────────────────────────────────────────

  /// Fully metallic surface (e.g. brushed steel).
  factory ARMaterial.metal({
    ARMaterialColor color = const ARMaterialColor(r: 0.8, g: 0.8, b: 0.85),
    double roughness = 0.2,
  }) =>
      ARMaterial(baseColor: color, metallic: 1.0, roughness: roughness);

  /// Matte non-metallic surface (e.g. plastic, ceramic).
  factory ARMaterial.matte({
    ARMaterialColor color = const ARMaterialColor(r: 0.5, g: 0.5, b: 0.5),
    double roughness = 0.9,
  }) =>
      ARMaterial(baseColor: color, metallic: 0.0, roughness: roughness);

  /// Glass-like transparent surface.
  factory ARMaterial.glass({
    ARMaterialColor color = const ARMaterialColor(r: 0.9, g: 0.95, b: 1.0),
    double opacity = 0.25,
  }) =>
      ARMaterial(
        baseColor: color,
        metallic: 0.0,
        roughness: 0.05,
        opacity: opacity,
        blendMode: ARBlendMode.alpha,
        doubleSided: true,
      );

  /// Emissive / glowing surface.
  factory ARMaterial.emissive({
    required ARMaterialColor color,
    double intensity = 3.0,
  }) =>
      ARMaterial(
        baseColor: color,
        emissiveColor: color,
        emissiveIntensity: intensity,
        metallic: 0.0,
        roughness: 1.0,
      );

  // ── copyWith ──────────────────────────────────────────────────────────────

  ARMaterial copyWith({
    ARMaterialColor? baseColor,
    double? metallic,
    double? roughness,
    double? ambientOcclusion,
    double? emissiveIntensity,
    ARMaterialColor? emissiveColor,
    double? opacity,
    bool? doubleSided,
    ARBlendMode? blendMode,
    String? baseColorTexturePath,
    String? normalMapPath,
    String? roughnessMapPath,
    String? metallicMapPath,
    String? occlusionMapPath,
    String? emissiveMapPath,
  }) =>
      ARMaterial(
        baseColor: baseColor ?? this.baseColor,
        metallic: metallic ?? this.metallic,
        roughness: roughness ?? this.roughness,
        ambientOcclusion: ambientOcclusion ?? this.ambientOcclusion,
        emissiveIntensity: emissiveIntensity ?? this.emissiveIntensity,
        emissiveColor: emissiveColor ?? this.emissiveColor,
        opacity: opacity ?? this.opacity,
        doubleSided: doubleSided ?? this.doubleSided,
        blendMode: blendMode ?? this.blendMode,
        baseColorTexturePath: baseColorTexturePath ?? this.baseColorTexturePath,
        normalMapPath: normalMapPath ?? this.normalMapPath,
        roughnessMapPath: roughnessMapPath ?? this.roughnessMapPath,
        metallicMapPath: metallicMapPath ?? this.metallicMapPath,
        occlusionMapPath: occlusionMapPath ?? this.occlusionMapPath,
        emissiveMapPath: emissiveMapPath ?? this.emissiveMapPath,
      );

  // ── Lerp ─────────────────────────────────────────────────────────────────

  /// Linearly interpolate every scalar/color field between [a] and [b].
  static ARMaterial lerp(ARMaterial a, ARMaterial b, double t) {
    final c = t.clamp(0.0, 1.0);
    return ARMaterial(
      baseColor: ARMaterialColor.lerp(a.baseColor, b.baseColor, c),
      metallic: a.metallic + (b.metallic - a.metallic) * c,
      roughness: a.roughness + (b.roughness - a.roughness) * c,
      ambientOcclusion:
          a.ambientOcclusion + (b.ambientOcclusion - a.ambientOcclusion) * c,
      opacity: a.opacity + (b.opacity - a.opacity) * c,
      doubleSided: c < 0.5 ? a.doubleSided : b.doubleSided,
      blendMode: c < 0.5 ? a.blendMode : b.blendMode,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'baseColor': baseColor.toMap(),
        'metallic': metallic,
        'roughness': roughness,
        'ambientOcclusion': ambientOcclusion,
        'emissiveIntensity': emissiveIntensity,
        'emissiveColor': emissiveColor?.toMap(),
        'opacity': opacity,
        'doubleSided': doubleSided,
        'blendMode': blendMode.name,
        'baseColorTexturePath': baseColorTexturePath,
        'normalMapPath': normalMapPath,
        'roughnessMapPath': roughnessMapPath,
        'metallicMapPath': metallicMapPath,
        'occlusionMapPath': occlusionMapPath,
        'emissiveMapPath': emissiveMapPath,
      };

  factory ARMaterial.fromMap(Map<dynamic, dynamic> m) => ARMaterial(
        baseColor: ARMaterialColor.fromMap(m['baseColor'] as Map),
        metallic: (m['metallic'] as num? ?? 0).toDouble(),
        roughness: (m['roughness'] as num? ?? 0.5).toDouble(),
        ambientOcclusion: (m['ambientOcclusion'] as num? ?? 1).toDouble(),
        emissiveIntensity: (m['emissiveIntensity'] as num?)?.toDouble(),
        emissiveColor: m['emissiveColor'] != null
            ? ARMaterialColor.fromMap(m['emissiveColor'] as Map)
            : null,
        opacity: (m['opacity'] as num? ?? 1).toDouble(),
        doubleSided: m['doubleSided'] as bool? ?? false,
        blendMode: ARBlendMode.values.firstWhere(
            (e) => e.name == m['blendMode'],
            orElse: () => ARBlendMode.opaque),
        baseColorTexturePath: m['baseColorTexturePath'] as String?,
        normalMapPath: m['normalMapPath'] as String?,
        roughnessMapPath: m['roughnessMapPath'] as String?,
        metallicMapPath: m['metallicMapPath'] as String?,
        occlusionMapPath: m['occlusionMapPath'] as String?,
        emissiveMapPath: m['emissiveMapPath'] as String?,
      );
}

// ─── ARMaterialColor ─────────────────────────────────────────────────────────

/// RGBA colour with double-precision components in [0, 1].
class ARMaterialColor {
  final double r, g, b, a;

  const ARMaterialColor({
    required this.r,
    required this.g,
    required this.b,
    this.a = 1.0,
  });

  // ── Named constructors ────────────────────────────────────────────────────

  const ARMaterialColor.white() : this(r: 1, g: 1, b: 1);
  const ARMaterialColor.black() : this(r: 0, g: 0, b: 0);
  const ARMaterialColor.red() : this(r: 1, g: 0, b: 0);
  const ARMaterialColor.green() : this(r: 0, g: 1, b: 0);
  const ARMaterialColor.blue() : this(r: 0, g: 0, b: 1);
  const ARMaterialColor.yellow() : this(r: 1, g: 1, b: 0);
  const ARMaterialColor.cyan() : this(r: 0, g: 1, b: 1);
  const ARMaterialColor.magenta() : this(r: 1, g: 0, b: 1);

  /// Create from a 0xAARRGGBB integer (e.g. `0xFF00E5FF`).
  factory ARMaterialColor.fromARGB(int value) => ARMaterialColor(
        a: ((value >> 24) & 0xFF) / 255.0,
        r: ((value >> 16) & 0xFF) / 255.0,
        g: ((value >> 8) & 0xFF) / 255.0,
        b: (value & 0xFF) / 255.0,
      );

  /// Create from a hex string like `'#FF00E5FF'` or `'00E5FF'`.
  factory ARMaterialColor.fromHex(String hex) {
    final h = hex.replaceAll('#', '').replaceAll('0x', '');
    final val = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return ARMaterialColor.fromARGB(val);
  }

  factory ARMaterialColor.fromMap(Map<dynamic, dynamic> m) => ARMaterialColor(
        r: (m['r'] as num? ?? 1).toDouble(),
        g: (m['g'] as num? ?? 1).toDouble(),
        b: (m['b'] as num? ?? 1).toDouble(),
        a: (m['a'] as num? ?? 1).toDouble(),
      );

  static ARMaterialColor lerp(ARMaterialColor a, ARMaterialColor b, double t) {
    final c = t.clamp(0.0, 1.0);
    return ARMaterialColor(
      r: a.r + (b.r - a.r) * c,
      g: a.g + (b.g - a.g) * c,
      b: a.b + (b.b - a.b) * c,
      a: a.a + (b.a - a.a) * c,
    );
  }

  ARMaterialColor withOpacity(double opacity) =>
      ARMaterialColor(r: r, g: g, b: b, a: opacity.clamp(0.0, 1.0));

  ARMaterialColor operator *(double factor) => ARMaterialColor(
        r: (r * factor).clamp(0.0, 1.0),
        g: (g * factor).clamp(0.0, 1.0),
        b: (b * factor).clamp(0.0, 1.0),
        a: a,
      );

  int toARGB() =>
      ((a * 255).round() << 24) |
      ((r * 255).round() << 16) |
      ((g * 255).round() << 8) |
      (b * 255).round();

  Map<String, double> toMap() => {'r': r, 'g': g, 'b': b, 'a': a};

  @override
  String toString() => 'ARMaterialColor(r:${r.toStringAsFixed(3)}, '
      'g:${g.toStringAsFixed(3)}, b:${b.toStringAsFixed(3)}, a:${a.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      other is ARMaterialColor &&
      r == other.r &&
      g == other.g &&
      b == other.b &&
      a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}
