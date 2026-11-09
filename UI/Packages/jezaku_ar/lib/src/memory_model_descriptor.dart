import 'package:ar_engine/ar_engine.dart';

import 'memory_model_placement.dart';

class JejakuMemoryModelDescriptor {
  JejakuMemoryModelDescriptor({
    required this.asset,
    JejakuMemoryModelPlacement? placement,
    ARVector3? position,
    ARQuaternion? rotation,
    ARVector3 scale = const ARVector3.one(),
    this.fallbackShape = ARPrimitiveShape.cube,
    this.material,
  }) : placement = placement ??
            JejakuMemoryModelPlacement(
              position: position,
              rotation: rotation,
              scale: scale,
            );

  final ARModelAsset asset;
  final JejakuMemoryModelPlacement placement;
  final ARPrimitiveShape fallbackShape;
  final ARMaterial? material;

  ARVector3? get position => placement.position;

  ARQuaternion? get rotation => placement.rotation;

  ARVector3 get scale => placement.scale;

  ARModelAssetValidationReport get validationReport => asset.validate();

  ARModelAsset get renderAsset {
    final safeFallbackSize = safeFallbackSizeMeters;
    if (safeFallbackSize == asset.fallbackSizeMeters) {
      return asset;
    }
    return ARModelAsset(
      path: asset.path,
      format: asset.format,
      source: asset.source,
      package: asset.package,
      fallbackSizeMeters: safeFallbackSize,
      centerOrigin: asset.centerOrigin,
      metadata: asset.metadata,
    );
  }

  ARVector3? get safeFallbackSizeMeters {
    final size = asset.fallbackSizeMeters;
    if (size == null) {
      return null;
    }
    if (_isPositiveFinite(size.x) &&
        _isPositiveFinite(size.y) &&
        _isPositiveFinite(size.z)) {
      return size;
    }
    return null;
  }

  static JejakuMemoryModelDescriptor? tryFromMetadata(
    Map<String, Object?> metadata,
  ) {
    final asset = ARModelAsset.tryFromMap(metadata['modelAsset']) ??
        _assetFromPathMetadata(metadata);
    if (asset == null) {
      return null;
    }

    return JejakuMemoryModelDescriptor(
      asset: asset,
      placement: JejakuMemoryModelPlacement.fromMetadata(metadata),
      fallbackShape: _primitiveShape(metadata['modelFallbackShape']) ??
          ARPrimitiveShape.cube,
      material: _material(metadata['modelMaterial']),
    );
  }

  static ARModelAsset? _assetFromPathMetadata(
    Map<String, Object?> metadata,
  ) {
    final path = _string(metadata['modelPath']);
    if (path == null) {
      return null;
    }
    return ARModelAsset.fromPath(
      path,
      format: _modelFormat(metadata['modelFormat']),
      source: _modelSource(metadata['modelSource']),
      package: _string(metadata['modelPackage']),
      fallbackSizeMeters: _vector(
        metadata['modelFallbackSizeMeters'] ?? metadata['modelSizeMeters'],
      ),
      centerOrigin: metadata['modelCenterOrigin'] as bool? ?? true,
      metadata: _metadata(metadata['modelMetadata']),
    );
  }

  static ARModelFormat? _modelFormat(Object? value) {
    final name = _string(value);
    if (name == null) {
      return null;
    }
    return ARModelFormat.values.firstWhere(
      (format) => format.name == name,
      orElse: () => ARModelFormat.custom,
    );
  }

  static ARModelAssetSource _modelSource(Object? value) {
    final name = _string(value);
    if (name == null) {
      return ARModelAssetSource.flutterAsset;
    }
    return ARModelAssetSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => ARModelAssetSource.flutterAsset,
    );
  }

  static ARPrimitiveShape? _primitiveShape(Object? value) {
    final name = _string(value);
    if (name == null) {
      return null;
    }
    return ARPrimitiveShape.values.firstWhere(
      (shape) => shape.name == name,
      orElse: () => ARPrimitiveShape.cube,
    );
  }

  static ARVector3? _vector(Object? value) {
    if (value is Map) {
      try {
        return ARVector3.fromMap(value);
      } on Object {
        return null;
      }
    }
    if (value is List && value.length >= 3) {
      final x = _number(value[0]);
      final y = _number(value[1]);
      final z = _number(value[2]);
      if (x != null && y != null && z != null) {
        return ARVector3(x, y, z);
      }
    }
    return null;
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

  static Map<String, Object?> _metadata(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }
    return Map<String, Object?>.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static double? _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }

  static bool _isPositiveFinite(double value) {
    return value.isFinite && value > 0;
  }
}
