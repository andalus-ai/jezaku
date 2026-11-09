import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';

enum JejakuMemoryModelAnchorAlignment {
  center,
  bottom,
  top,
}

enum JejakuMemoryModelFacingMode {
  fixed,
  billboard,
  horizontalBillboard,
}

class JejakuMemoryModelPlacement {
  const JejakuMemoryModelPlacement({
    this.position,
    this.offset = const ARVector3.zero(),
    this.rotation,
    this.scale = const ARVector3.one(),
    this.forwardOffsetMeters,
    this.verticalOffsetMeters = 0,
    this.anchorAlignment = JejakuMemoryModelAnchorAlignment.center,
    this.facingMode = JejakuMemoryModelFacingMode.fixed,
  });

  factory JejakuMemoryModelPlacement.fromMetadata(
    Map<String, Object?> metadata,
  ) {
    final placement = _map(metadata['modelPlacement']);
    return JejakuMemoryModelPlacement(
      position:
          _vector(placement?['position']) ?? _vector(metadata['modelPosition']),
      offset: _vector(placement?['offset']) ??
          _vector(metadata['modelOffset']) ??
          const ARVector3.zero(),
      rotation: _quaternion(placement?['rotation']) ??
          _rotationFromEulerDegrees(
            placement?['rotationEulerDegrees'] ??
                placement?['eulerDegrees'] ??
                metadata['modelRotationEulerDegrees'],
          ) ??
          _quaternion(metadata['modelRotation']),
      scale: _scaleVector(placement?['scale']) ??
          _uniformScale(placement?['uniformScale']) ??
          _scaleVector(metadata['modelScale']) ??
          _uniformScale(metadata['modelUniformScale']) ??
          const ARVector3.one(),
      forwardOffsetMeters: _positiveNumber(
        placement?['forwardOffsetMeters'] ??
            metadata['modelForwardOffsetMeters'],
      ),
      verticalOffsetMeters: _number(
            placement?['verticalOffsetMeters'] ??
                metadata['modelVerticalOffsetMeters'],
          ) ??
          0,
      anchorAlignment: _anchorAlignment(
        placement?['anchorAlignment'] ?? metadata['modelAnchorAlignment'],
      ),
      facingMode: _facingMode(
        placement?['facingMode'] ?? metadata['modelFacingMode'],
      ),
    );
  }

  final ARVector3? position;
  final ARVector3 offset;
  final ARQuaternion? rotation;
  final ARVector3 scale;
  final double? forwardOffsetMeters;
  final double verticalOffsetMeters;
  final JejakuMemoryModelAnchorAlignment anchorAlignment;
  final JejakuMemoryModelFacingMode facingMode;

  bool get hasExplicitPosition => position != null;

  double forwardOffsetOr(double fallbackMeters) {
    final configured = forwardOffsetMeters;
    if (configured == null || !configured.isFinite || configured <= 0) {
      return fallbackMeters;
    }
    return configured;
  }

  ARVector3 defaultProjectionPosition(double fallbackForwardOffsetMeters) {
    return ARVector3(0, 0, -forwardOffsetOr(fallbackForwardOffsetMeters));
  }

  ARVector3 resolvePosition({
    required ARVector3 basePosition,
    ARVector3? fallbackSizeMeters,
  }) {
    final origin = position ?? basePosition;
    return origin +
        offset +
        ARVector3(0, verticalOffsetMeters, 0) +
        _anchorAlignmentOffset(fallbackSizeMeters);
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'position': position?.toMap(),
      'offset': offset.toMap(),
      'rotation': rotation?.toMap(),
      'scale': scale.toMap(),
      'forwardOffsetMeters': forwardOffsetMeters,
      'verticalOffsetMeters': verticalOffsetMeters,
      'anchorAlignment': anchorAlignment.name,
      'facingMode': facingMode.name,
      'hasExplicitPosition': hasExplicitPosition,
    };
  }

  ARVector3 _anchorAlignmentOffset(ARVector3? fallbackSizeMeters) {
    final height = fallbackSizeMeters?.y;
    if (height == null || !height.isFinite || height <= 0) {
      return const ARVector3.zero();
    }
    final scaledHalfHeight = height * scale.y.abs() / 2;
    return switch (anchorAlignment) {
      JejakuMemoryModelAnchorAlignment.center => const ARVector3.zero(),
      JejakuMemoryModelAnchorAlignment.bottom =>
        ARVector3(0, scaledHalfHeight, 0),
      JejakuMemoryModelAnchorAlignment.top =>
        ARVector3(0, -scaledHalfHeight, 0),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is JejakuMemoryModelPlacement &&
        position == other.position &&
        offset == other.offset &&
        rotation == other.rotation &&
        scale == other.scale &&
        forwardOffsetMeters == other.forwardOffsetMeters &&
        verticalOffsetMeters == other.verticalOffsetMeters &&
        anchorAlignment == other.anchorAlignment &&
        facingMode == other.facingMode;
  }

  @override
  int get hashCode => Object.hash(
        position,
        offset,
        rotation,
        scale,
        forwardOffsetMeters,
        verticalOffsetMeters,
        anchorAlignment,
        facingMode,
      );

  static Map<dynamic, dynamic>? _map(Object? value) {
    return value is Map ? value : null;
  }

  static ARVector3? _vector(Object? value) {
    if (value is Map) {
      try {
        final vector = ARVector3.fromMap(value);
        return _isFiniteVector(vector) ? vector : null;
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

  static ARVector3? _scaleVector(Object? value) {
    final vector = _vector(value);
    if (vector != null) {
      return _isUsableScale(vector) ? vector : null;
    }
    return _uniformScale(value);
  }

  static ARVector3? _uniformScale(Object? value) {
    final scale = _positiveNumber(value);
    if (scale == null) {
      return null;
    }
    return ARVector3(scale, scale, scale);
  }

  static ARQuaternion? _quaternion(Object? value) {
    if (value is Map) {
      try {
        return ARQuaternion.fromMap(value).normalized;
      } on Object {
        return null;
      }
    }
    if (value is List && value.length >= 4) {
      final x = _number(value[0]);
      final y = _number(value[1]);
      final z = _number(value[2]);
      final w = _number(value[3]);
      if (x != null && y != null && z != null && w != null) {
        return ARQuaternion(x, y, z, w).normalized;
      }
    }
    return null;
  }

  static ARQuaternion? _rotationFromEulerDegrees(Object? value) {
    final vector = _vector(value);
    if (vector == null) {
      return null;
    }
    return ARQuaternion.euler(
      _degreesToRadians(vector.x),
      _degreesToRadians(vector.y),
      _degreesToRadians(vector.z),
    );
  }

  static JejakuMemoryModelAnchorAlignment _anchorAlignment(Object? value) {
    final name = _normalizedName(value);
    return switch (name) {
      'bottom' ||
      'base' ||
      'floor' ||
      'ground' =>
        JejakuMemoryModelAnchorAlignment.bottom,
      'top' || 'ceiling' => JejakuMemoryModelAnchorAlignment.top,
      _ => JejakuMemoryModelAnchorAlignment.center,
    };
  }

  static JejakuMemoryModelFacingMode _facingMode(Object? value) {
    final name = _normalizedName(value);
    return switch (name) {
      'billboard' ||
      'camera' ||
      'camerafacing' =>
        JejakuMemoryModelFacingMode.billboard,
      'horizontalbillboard' ||
      'yaxisbillboard' ||
      'yawbillboard' =>
        JejakuMemoryModelFacingMode.horizontalBillboard,
      _ => JejakuMemoryModelFacingMode.fixed,
    };
  }

  static String? _normalizedName(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim().replaceAll(RegExp(r'[\s_-]+'), '').toLowerCase();
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

  static double? _positiveNumber(Object? value) {
    final number = _number(value);
    if (number == null || number <= 0) {
      return null;
    }
    return number;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  static bool _isFiniteVector(ARVector3 value) {
    return value.x.isFinite && value.y.isFinite && value.z.isFinite;
  }

  static bool _isUsableScale(ARVector3 value) {
    return _isFiniteVector(value) &&
        value.x.abs() > 1e-9 &&
        value.y.abs() > 1e-9 &&
        value.z.abs() > 1e-9;
  }
}
