import 'package:collection/collection.dart';

import 'models/ar_vector3.dart';

const _mapEquality = DeepCollectionEquality();

/// Supported file/container formats for model-backed AR nodes.
enum ARModelFormat { glb, gltf, obj, usdz, scn, reality, custom }

/// Where the model asset is expected to be loaded from by the platform layer.
enum ARModelAssetSource { flutterAsset, file, network, bundle }

/// A typed description of a 3D model that can be attached to an [ARNode].
class ARModelAsset {
  const ARModelAsset({
    required this.path,
    required this.format,
    this.source = ARModelAssetSource.flutterAsset,
    this.package,
    this.fallbackSizeMeters,
    this.centerOrigin = true,
    this.metadata = const <String, Object?>{},
  });

  factory ARModelAsset.fromPath(
    String path, {
    ARModelFormat? format,
    ARModelAssetSource source = ARModelAssetSource.flutterAsset,
    String? package,
    ARVector3? fallbackSizeMeters,
    bool centerOrigin = true,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Must not be blank.');
    }
    return ARModelAsset(
      path: normalizedPath,
      format: format ?? inferFormat(normalizedPath),
      source: source,
      package: package,
      fallbackSizeMeters: fallbackSizeMeters,
      centerOrigin: centerOrigin,
      metadata: Map<String, Object?>.unmodifiable(metadata),
    );
  }

  factory ARModelAsset.fromMap(Map<dynamic, dynamic> map) {
    return ARModelAsset.fromPath(
      _string(map['path'], ''),
      format: _format(map['format']),
      source: _source(map['source']),
      package: _nullableString(map['package']),
      fallbackSizeMeters: map['fallbackSizeMeters'] is Map
          ? ARVector3.fromMap(map['fallbackSizeMeters'] as Map)
          : null,
      centerOrigin: map['centerOrigin'] as bool? ?? true,
      metadata: _metadata(map['metadata']),
    );
  }

  static ARModelAsset? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARModelAsset.fromMap(value);
    } on Object {
      return null;
    }
  }

  static ARModelFormat inferFormat(String path) {
    final extension =
        path.trim().split('?').first.split('.').last.toLowerCase();
    return switch (extension) {
      'glb' => ARModelFormat.glb,
      'gltf' => ARModelFormat.gltf,
      'obj' => ARModelFormat.obj,
      'usdz' => ARModelFormat.usdz,
      'scn' => ARModelFormat.scn,
      'reality' => ARModelFormat.reality,
      _ => ARModelFormat.custom,
    };
  }

  final String path;
  final ARModelFormat format;
  final ARModelAssetSource source;
  final String? package;
  final ARVector3? fallbackSizeMeters;
  final bool centerOrigin;
  final Map<String, Object?> metadata;

  bool get isFlutterAsset => source == ARModelAssetSource.flutterAsset;

  Map<String, Object?> toMap() => <String, Object?>{
        'path': path,
        'format': format.name,
        'source': source.name,
        'package': package,
        'fallbackSizeMeters': fallbackSizeMeters?.toMap(),
        'centerOrigin': centerOrigin,
        'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is ARModelAsset &&
      path == other.path &&
      format == other.format &&
      source == other.source &&
      package == other.package &&
      fallbackSizeMeters == other.fallbackSizeMeters &&
      centerOrigin == other.centerOrigin &&
      _mapEquality.equals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        path,
        format,
        source,
        package,
        fallbackSizeMeters,
        centerOrigin,
        _mapEquality.hash(metadata),
      );
}

ARModelFormat _format(Object? value) {
  if (value is String) {
    return ARModelFormat.values.firstWhere(
      (format) => format.name == value,
      orElse: () => ARModelFormat.custom,
    );
  }
  return ARModelFormat.custom;
}

ARModelAssetSource _source(Object? value) {
  if (value is String) {
    return ARModelAssetSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => ARModelAssetSource.flutterAsset,
    );
  }
  return ARModelAssetSource.flutterAsset;
}

String _string(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

Map<String, Object?> _metadata(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.unmodifiable(
    value.map((key, value) => MapEntry(key.toString(), value)),
  );
}
