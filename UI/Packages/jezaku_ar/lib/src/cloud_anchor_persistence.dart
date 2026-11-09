import 'package:ar_engine/ar_engine.dart';

import 'geo_anchor.dart';
import 'memory_scene.dart';

class JejakuMemoryCloudAnchor {
  const JejakuMemoryCloudAnchor({
    required this.memoryId,
    required this.localAnchorId,
    required this.cloudAnchorId,
    this.expiresAt,
  });

  final String memoryId;
  final String localAnchorId;
  final String cloudAnchorId;
  final DateTime? expiresAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'memoryId': memoryId,
      'localAnchorId': localAnchorId,
      'cloudAnchorId': cloudAnchorId,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory JejakuMemoryCloudAnchor.fromMap(Map<String, Object?> map) {
    return JejakuMemoryCloudAnchor(
      memoryId: _requiredString(map, 'memoryId'),
      localAnchorId: _requiredString(map, 'localAnchorId'),
      cloudAnchorId: _requiredString(map, 'cloudAnchorId'),
      expiresAt: _dateTimeOrNull(map['expiresAt'], 'expiresAt'),
    );
  }

  static String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw ArgumentError.value(value, key, 'Must be a non-empty string.');
  }

  static DateTime? _dateTimeOrNull(Object? value, String key) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.parse(value);
    }
    throw ArgumentError.value(value, key, 'Must be an ISO-8601 date string.');
  }
}

class JejakuResolvedMemoryCloudAnchor {
  const JejakuResolvedMemoryCloudAnchor({
    required this.record,
    required this.anchor,
  });

  final JejakuMemoryCloudAnchor record;
  final ARAnchor anchor;
}

class JejakuMemoryCloudAnchorManager {
  const JejakuMemoryCloudAnchorManager({
    required ARController controller,
  }) : _controller = controller;

  final ARController _controller;

  Future<JejakuMemoryCloudAnchor?> hostPlacedMemory({
    required JejakuPlacedMemory placed,
    int ttlDays = 30,
    DateTime? hostedAt,
  }) async {
    if (ttlDays < 0 || ttlDays > 365) {
      throw RangeError.range(ttlDays, 0, 365, 'ttlDays');
    }

    final cloudId = await _controller.hostCloudAnchor(
      placed.anchorId,
      ttlDays: ttlDays,
    );
    if (cloudId == null || cloudId.trim().isEmpty) {
      return null;
    }

    final baseTime = hostedAt ?? DateTime.now().toUtc();
    return JejakuMemoryCloudAnchor(
      memoryId: placed.memory.id,
      localAnchorId: placed.anchorId,
      cloudAnchorId: cloudId,
      expiresAt: ttlDays > 0 ? baseTime.add(Duration(days: ttlDays)) : null,
    );
  }

  Future<JejakuResolvedMemoryCloudAnchor?> resolveMemoryAnchor(
    JejakuMemoryCloudAnchor record,
  ) async {
    final anchor = await _controller.resolveCloudAnchor(record.cloudAnchorId);
    if (anchor == null) {
      return null;
    }
    return JejakuResolvedMemoryCloudAnchor(
      record: record,
      anchor: anchor,
    );
  }

  Future<JejakuPlacedMemory?> resolveAndPlaceMemory({
    required JejakuMemoryARScene scene,
    required JejakuMemoryCloudAnchor record,
    required JejakuGeoAnchor memory,
  }) async {
    if (record.memoryId != memory.id) {
      throw ArgumentError.value(
        memory.id,
        'memory.id',
        'Must match the cloud anchor record memoryId.',
      );
    }
    final resolved = await resolveMemoryAnchor(record);
    if (resolved == null) {
      return null;
    }
    return scene.placeMemoryAtAnchor(
      anchor: resolved.anchor,
      memory: memory,
    );
  }
}
