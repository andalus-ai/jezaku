import '../ar_node.dart';
import '../ar_model_asset.dart';
import '../models/ar_vector3.dart';
import '../models/ar_quaternion.dart';

/// Fluent builder for [ARNode].
///
/// Example:
/// ```dart
/// final node = ARNodeBuilder('my_sphere')
///   .sphere(radius: 0.08)
///   .at(x: 0, y: 0.5, z: -1.0)
///   .material(ARMaterial.metal(color: ARMaterialColor.cyan()))
///   .withPhysics()
///   .visible(true)
///   .build();
/// ```
class ARNodeBuilder {
  final String _id;

  ARVector3 _position = const ARVector3.zero();
  ARQuaternion _rotation = const ARQuaternion.identity();
  ARVector3 _scale = const ARVector3.one();
  ARMaterial? _material;
  ARNodeContentType _contentType = ARNodeContentType.primitive;
  ARPrimitiveShape _shape = ARPrimitiveShape.cube;
  ARVector3? _primitiveSize;
  String? _modelPath;
  ARModelAsset? _modelAsset;
  bool _isVisible = true;
  int _renderOrder = 0;
  bool _castsShadow = true;
  bool _receivesShadow = true;
  List<ARNode> _children = const [];
  Map<String, dynamic> _metadata = const {};

  ARNodeBuilder(this._id);

  // ── Position ──────────────────────────────────────────────────────────────

  ARNodeBuilder at({double x = 0, double y = 0, double z = 0}) {
    _position = ARVector3(x, y, z);
    return this;
  }

  ARNodeBuilder position(ARVector3 v) {
    _position = v;
    return this;
  }

  // ── Rotation ──────────────────────────────────────────────────────────────

  ARNodeBuilder rotation(ARQuaternion q) {
    _rotation = q;
    return this;
  }

  ARNodeBuilder lookAt(ARVector3 target) {
    _rotation = ARQuaternion.lookRotation(target - _position);
    return this;
  }

  // ── Scale ─────────────────────────────────────────────────────────────────

  ARNodeBuilder scale(ARVector3 s) {
    _scale = s;
    return this;
  }

  ARNodeBuilder uniformScale(double s) {
    _scale = ARVector3(s, s, s);
    return this;
  }

  // ── Primitive shapes ──────────────────────────────────────────────────────

  ARNodeBuilder cube({double size = 0.1}) {
    _contentType = ARNodeContentType.primitive;
    _modelPath = null;
    _modelAsset = null;
    _shape = ARPrimitiveShape.cube;
    _primitiveSize = ARVector3(size, size, size);
    _scale = const ARVector3.one();
    return this;
  }

  ARNodeBuilder box({double w = 0.1, double h = 0.1, double d = 0.1}) {
    _contentType = ARNodeContentType.primitive;
    _modelPath = null;
    _modelAsset = null;
    _shape = ARPrimitiveShape.cube;
    _primitiveSize = ARVector3(w, h, d);
    _scale = const ARVector3.one();
    return this;
  }

  ARNodeBuilder sphere({double radius = 0.05}) {
    _contentType = ARNodeContentType.primitive;
    _modelPath = null;
    _modelAsset = null;
    _shape = ARPrimitiveShape.sphere;
    _primitiveSize = ARVector3(radius * 2, radius * 2, radius * 2);
    _scale = const ARVector3.one();
    return this;
  }

  ARNodeBuilder cylinder({double radius = 0.05, double height = 0.1}) {
    _contentType = ARNodeContentType.primitive;
    _modelPath = null;
    _modelAsset = null;
    _shape = ARPrimitiveShape.cylinder;
    _primitiveSize = ARVector3(radius * 2, height, radius * 2);
    _scale = const ARVector3.one();
    return this;
  }

  ARNodeBuilder capsule({double radius = 0.04, double height = 0.12}) {
    _contentType = ARNodeContentType.primitive;
    _modelPath = null;
    _modelAsset = null;
    _shape = ARPrimitiveShape.capsule;
    _primitiveSize = ARVector3(radius * 2, height, radius * 2);
    _scale = const ARVector3.one();
    return this;
  }

  ARNodeBuilder plane({double width = 0.1, double depth = 0.1}) {
    _contentType = ARNodeContentType.primitive;
    _modelPath = null;
    _modelAsset = null;
    _shape = ARPrimitiveShape.plane;
    _primitiveSize = ARVector3(width, 0.001, depth);
    _scale = const ARVector3.one();
    return this;
  }

  // ── 3D model ──────────────────────────────────────────────────────────────

  ARNodeBuilder model(
    String path, {
    ARNodeContentType type = ARNodeContentType.glb,
    ARModelAssetSource source = ARModelAssetSource.flutterAsset,
    String? package,
    ARVector3? fallbackSizeMeters,
    bool centerOrigin = true,
  }) {
    final asset = ARModelAsset.fromPath(
      path,
      format:
          _modelFormatForContentType(type) ?? ARModelAsset.inferFormat(path),
      source: source,
      package: package,
      fallbackSizeMeters: fallbackSizeMeters,
      centerOrigin: centerOrigin,
    );
    return modelAsset(asset);
  }

  ARNodeBuilder modelAsset(ARModelAsset asset) {
    _contentType = _contentTypeForModelAsset(asset);
    _modelPath = asset.path;
    _modelAsset = asset;
    _primitiveSize = asset.fallbackSizeMeters;
    return this;
  }

  ARNodeBuilder glb(
    String path, {
    ARModelAssetSource source = ARModelAssetSource.flutterAsset,
    String? package,
    ARVector3? fallbackSizeMeters,
  }) =>
      model(
        path,
        type: ARNodeContentType.glb,
        source: source,
        package: package,
        fallbackSizeMeters: fallbackSizeMeters,
      );

  ARNodeBuilder gltf(
    String path, {
    ARModelAssetSource source = ARModelAssetSource.flutterAsset,
    String? package,
    ARVector3? fallbackSizeMeters,
  }) =>
      model(
        path,
        type: ARNodeContentType.gltf,
        source: source,
        package: package,
        fallbackSizeMeters: fallbackSizeMeters,
      );

  ARNodeBuilder usdz(
    String path, {
    ARModelAssetSource source = ARModelAssetSource.flutterAsset,
    String? package,
    ARVector3? fallbackSizeMeters,
  }) =>
      model(
        path,
        type: ARNodeContentType.usdz,
        source: source,
        package: package,
        fallbackSizeMeters: fallbackSizeMeters,
      );

  ARNodeBuilder obj(
    String path, {
    ARModelAssetSource source = ARModelAssetSource.flutterAsset,
    String? package,
    ARVector3? fallbackSizeMeters,
  }) =>
      model(
        path,
        type: ARNodeContentType.obj,
        source: source,
        package: package,
        fallbackSizeMeters: fallbackSizeMeters,
      );

  // ── Material ──────────────────────────────────────────────────────────────

  ARNodeBuilder material(ARMaterial m) {
    _material = m;
    return this;
  }

  ARNodeBuilder color(ARMaterialColor c) {
    _material = (_material ?? const ARMaterial()).copyWith(baseColor: c);
    return this;
  }

  ARNodeBuilder metallic(double v) {
    _material = (_material ?? const ARMaterial()).copyWith(metallic: v);
    return this;
  }

  ARNodeBuilder roughness(double v) {
    _material = (_material ?? const ARMaterial()).copyWith(roughness: v);
    return this;
  }

  ARNodeBuilder opacity(double v) {
    _material = (_material ?? const ARMaterial()).copyWith(
        opacity: v, blendMode: v < 1 ? ARBlendMode.alpha : ARBlendMode.opaque);
    return this;
  }

  ARNodeBuilder glowing({ARMaterialColor? color, double intensity = 2.0}) {
    final c = color ?? const ARMaterialColor.white();
    _material = ARMaterial.emissive(color: c, intensity: intensity);
    return this;
  }

  // ── Visibility & rendering ────────────────────────────────────────────────

  ARNodeBuilder visible(bool v) {
    _isVisible = v;
    return this;
  }

  ARNodeBuilder hidden() {
    _isVisible = false;
    return this;
  }

  ARNodeBuilder renderOrder(int o) {
    _renderOrder = o;
    return this;
  }

  ARNodeBuilder shadows({bool casts = true, bool receives = true}) {
    _castsShadow = casts;
    _receivesShadow = receives;
    return this;
  }

  // ── Hierarchy ─────────────────────────────────────────────────────────────

  ARNodeBuilder children(List<ARNode> c) {
    _children = c;
    return this;
  }

  ARNodeBuilder addChild(ARNode child) {
    _children = [..._children, child];
    return this;
  }

  // ── Metadata ──────────────────────────────────────────────────────────────

  ARNodeBuilder tag(String key, dynamic value) {
    _metadata = {..._metadata, key: value};
    return this;
  }

  ARNodeBuilder meta(Map<String, dynamic> m) {
    _metadata = {..._metadata, ...m};
    return this;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  ARNode build() => ARNode(
        id: _id,
        position: _position,
        rotation: _rotation,
        scale: _scale,
        contentType: _contentType,
        modelPath: _modelPath,
        modelAsset: _modelAsset,
        primitiveShape: _shape,
        primitiveSize: _primitiveSize,
        material: _material,
        children: _children,
        castsShadow: _castsShadow,
        receivesShadow: _receivesShadow,
        isVisible: _isVisible,
        renderOrder: _renderOrder,
        metadata: _metadata,
      );
}

ARModelFormat? _modelFormatForContentType(ARNodeContentType type) {
  return switch (type) {
    ARNodeContentType.glb => ARModelFormat.glb,
    ARNodeContentType.gltf => ARModelFormat.gltf,
    ARNodeContentType.obj => ARModelFormat.obj,
    ARNodeContentType.usdz => ARModelFormat.usdz,
    ARNodeContentType.scn => ARModelFormat.scn,
    ARNodeContentType.reality => ARModelFormat.reality,
    ARNodeContentType.custom => ARModelFormat.custom,
    ARNodeContentType.primitive => null,
  };
}

ARNodeContentType _contentTypeForModelAsset(ARModelAsset asset) {
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
