import 'dart:async';
import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/ar_capture_diagnostics_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capturedAnchorMemoriesKey = 'jejaku.captured_anchor_memories';

final anchorMemoryStoreProvider = Provider<AnchorMemoryStore>((ref) {
  return InMemoryAnchorMemoryStore();
});

persistentAnchorMemoryStoreOverride({
  required SharedPreferences preferences,
}) {
  return anchorMemoryStoreProvider.overrideWith((ref) {
    return SharedPreferencesAnchorMemoryStore(preferences: preferences);
  });
}

abstract class AnchorMemoryStore {
  List<AnchorMemory> loadCapturedMemories();

  void saveCapturedMemories(List<AnchorMemory> memories);
}

class InMemoryAnchorMemoryStore implements AnchorMemoryStore {
  List<AnchorMemory> _memories = const <AnchorMemory>[];

  @override
  List<AnchorMemory> loadCapturedMemories() {
    return List<AnchorMemory>.unmodifiable(_memories);
  }

  @override
  void saveCapturedMemories(List<AnchorMemory> memories) {
    _memories = List<AnchorMemory>.unmodifiable(memories);
  }
}

class SharedPreferencesAnchorMemoryStore implements AnchorMemoryStore {
  const SharedPreferencesAnchorMemoryStore({
    required SharedPreferences preferences,
    String key = _capturedAnchorMemoriesKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  @override
  List<AnchorMemory> loadCapturedMemories() {
    final encodedMemories = _preferences.getString(_key);
    if (encodedMemories == null || encodedMemories.trim().isEmpty) {
      return const <AnchorMemory>[];
    }

    try {
      final decoded = jsonDecode(encodedMemories);
      if (decoded is! List) {
        clear();
        return const <AnchorMemory>[];
      }
      return List<AnchorMemory>.unmodifiable(
        decoded
            .whereType<Map>()
            .map((memory) => _memoryFromJson(Map<String, Object?>.from(memory)))
            .whereType<AnchorMemory>(),
      );
    } on Object {
      clear();
      return const <AnchorMemory>[];
    }
  }

  @override
  void saveCapturedMemories(List<AnchorMemory> memories) {
    unawaited(
      _preferences.setString(
        _key,
        jsonEncode([
          for (final memory in memories) _memoryToJson(memory),
        ]),
      ),
    );
  }

  void clear() {
    unawaited(_preferences.remove(_key));
  }
}

Map<String, Object?> _memoryToJson(AnchorMemory memory) {
  return <String, Object?>{
    'schemaVersion': 1,
    'id': memory.id,
    'title': memory.title,
    'caption': memory.caption,
    'distanceLabel': memory.distanceLabel,
    'capturedAgo': memory.capturedAgo,
    'locationLabel': memory.locationLabel,
    'latitude': memory.latitude,
    'longitude': memory.longitude,
    'reactions': memory.reactions,
    'capturedAt': memory.capturedAt?.toIso8601String(),
    'syncStatus': memory.syncStatus.name,
    'syncReason': memory.syncReason.name,
    'moderationStatus': memory.moderationStatus.name,
    'reportReason': memory.reportReason,
    'reportCount': memory.reportCount,
    'isPrivate': memory.isPrivate,
    'allowComments': memory.allowComments,
    'hasArExperience': memory.hasArExperience,
    'captureMetadata': _captureMetadataToJson(memory.captureMetadata),
    'mediaAttachment': _mediaAttachmentToJson(memory.mediaAttachment),
  };
}

AnchorMemory? _memoryFromJson(Map<String, Object?> json) {
  final metadataJson = json['captureMetadata'];
  if (metadataJson is! Map) {
    return null;
  }
  return AnchorMemory(
    id: _string(json['id'], 'captured_local'),
    title: _string(json['title'], 'New AR memory'),
    caption: _string(json['caption'], ''),
    distanceLabel: _string(json['distanceLabel'], '30 m radius'),
    capturedAgo: _string(json['capturedAgo'], 'Just now'),
    locationLabel: _string(json['locationLabel'], '-6.9175, 107.6191'),
    latitude: _double(json['latitude'], -6.9175),
    longitude: _double(json['longitude'], 107.6191),
    reactions: _int(json['reactions'], 0),
    capturedAt: _date(json['capturedAt']),
    syncStatus: _enumByName(
      AnchorSyncStatus.values,
      json['syncStatus'],
      AnchorSyncStatus.queued,
    ),
    syncReason: _enumByName(
      AnchorSyncReason.values,
      json['syncReason'],
      AnchorSyncReason.newCapture,
    ),
    moderationStatus: _enumByName(
      AnchorModerationStatus.values,
      json['moderationStatus'],
      AnchorModerationStatus.approved,
    ),
    reportReason: json['reportReason'] as String?,
    reportCount: _int(json['reportCount'], 0),
    isPrivate: _bool(json['isPrivate']),
    allowComments: _bool(json['allowComments'], fallback: true),
    hasArExperience: _bool(json['hasArExperience'], fallback: true),
    captureMetadata: _captureMetadataFromJson(
      Map<String, Object?>.from(metadataJson),
    ),
    mediaAttachment: _mediaAttachmentFromJson(json['mediaAttachment']),
  );
}

Map<String, Object?> _captureMetadataToJson(AnchorCaptureMetadata metadata) {
  return <String, Object?>{
    'altitudeMeters': metadata.altitudeMeters,
    'headingDegrees': metadata.headingDegrees,
    'pitchDegrees': metadata.pitchDegrees,
    'rollDegrees': metadata.rollDegrees,
    'gpsAccuracyMeters': metadata.gpsAccuracyMeters,
    'anchorType': metadata.anchorType,
    'captureSource': metadata.captureSource,
    'correctionEastMeters': metadata.correctionEastMeters,
    'correctionNorthMeters': metadata.correctionNorthMeters,
    'correctionUpMeters': metadata.correctionUpMeters,
    'manualCorrectionSavedAt':
        metadata.manualCorrectionSavedAt?.toIso8601String(),
    'localAnchorId': metadata.localAnchorId,
    'localAnchorPose': metadata.localAnchorPose?.toMap(),
    'cloudAnchorId': metadata.cloudAnchorId,
    'cloudAnchorExpiresAt': metadata.cloudAnchorExpiresAt?.toIso8601String(),
  };
}

AnchorCaptureMetadata _captureMetadataFromJson(Map<String, Object?> json) {
  return AnchorCaptureMetadata(
    altitudeMeters: _double(json['altitudeMeters'], 714.2),
    headingDegrees: _double(json['headingDegrees'], 245),
    pitchDegrees: _double(json['pitchDegrees'], -2),
    rollDegrees: _double(json['rollDegrees'], 0.4),
    gpsAccuracyMeters: _double(json['gpsAccuracyMeters'], 3.2),
    anchorType: _string(json['anchorType'], 'Hybrid geo/orientation'),
    captureSource: _string(json['captureSource'], 'GPS + compass + gyro'),
    correctionEastMeters: _double(json['correctionEastMeters'], 0),
    correctionNorthMeters: _double(json['correctionNorthMeters'], 0),
    correctionUpMeters: _double(json['correctionUpMeters'], 0),
    manualCorrectionSavedAt: _date(json['manualCorrectionSavedAt']),
    localAnchorId: json['localAnchorId'] as String?,
    localAnchorPose: _localPoseFromJson(json['localAnchorPose']),
    cloudAnchorId: json['cloudAnchorId'] as String?,
    cloudAnchorExpiresAt: _date(json['cloudAnchorExpiresAt']),
  );
}

AnchorLocalPose? _localPoseFromJson(Object? value) {
  if (value is! Map) {
    return null;
  }
  return AnchorLocalPose.fromMap(Map<String, Object?>.from(value));
}

Map<String, Object?>? _mediaAttachmentToJson(
  AnchorMediaAttachment? attachment,
) {
  if (attachment == null) {
    return null;
  }
  return <String, Object?>{
    'type': attachment.type.name,
    'mediaId': attachment.mediaId,
    'storagePath': attachment.storagePath,
    'storedAt': attachment.storedAt?.toIso8601String(),
    'filePath': attachment.filePath,
    'durationMs': attachment.duration?.inMilliseconds,
    'frameCount': attachment.frameCount,
    'targetFps': attachment.targetFps,
    'videoBitrateKbps': attachment.videoBitrateKbps,
    'outputFormat': attachment.outputFormat,
    'includesUIOverlay': attachment.includesUIOverlay,
    'includesAudio': attachment.includesAudio,
    'fileSizeBytes': attachment.fileSizeBytes,
    'recordingQualityReviewedAt':
        attachment.recordingQualityReviewedAt?.toIso8601String(),
    'arDiagnostics': normalizedARCaptureDiagnosticsPayload(
      attachment.arDiagnostics,
    ),
    'modelAsset': attachment.modelAsset?.toMap(),
  };
}

AnchorMediaAttachment? _mediaAttachmentFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  final map = Map<String, Object?>.from(json);
  return AnchorMediaAttachment(
    type: _enumByName(
      AnchorMediaType.values,
      map['type'],
      AnchorMediaType.cameraPhoto,
    ),
    mediaId: map['mediaId'] as String?,
    storagePath: map['storagePath'] as String?,
    storedAt: _date(map['storedAt']),
    filePath: map['filePath'] as String?,
    duration: _duration(map['durationMs']),
    frameCount: _intOrNull(map['frameCount']),
    targetFps: _intOrNull(map['targetFps']),
    videoBitrateKbps: _intOrNull(map['videoBitrateKbps']),
    outputFormat: map['outputFormat'] as String?,
    includesUIOverlay: map['includesUIOverlay'] is bool
        ? map['includesUIOverlay'] as bool
        : true,
    includesAudio:
        map['includesAudio'] is bool ? map['includesAudio'] as bool : false,
    fileSizeBytes: _intOrNull(map['fileSizeBytes']),
    recordingQualityReviewedAt: _date(map['recordingQualityReviewedAt']),
    arDiagnostics: normalizedARCaptureDiagnosticsPayload(map['arDiagnostics']),
    modelAsset: ARModelAsset.tryFromMap(map['modelAsset']),
  );
}

String _string(Object? value, String fallback) {
  return value is String && value.isNotEmpty ? value : fallback;
}

double _double(Object? value, double fallback) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return fallback;
}

int _int(Object? value, int fallback) {
  if (value is num && value.isFinite) {
    return value.toInt();
  }
  return fallback;
}

int? _intOrNull(Object? value) {
  if (value is num && value.isFinite) {
    return value.toInt();
  }
  return null;
}

bool _bool(Object? value, {bool fallback = false}) {
  return value is bool ? value : fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

Duration? _duration(Object? value) {
  final milliseconds = _intOrNull(value);
  return milliseconds == null ? null : Duration(milliseconds: milliseconds);
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
