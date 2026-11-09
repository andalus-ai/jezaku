import 'dart:convert';

import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/ar_capture_diagnostics_payload.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';

enum AnchorSyncBatchType {
  fullQueue('full_queue'),
  uploadMetadata('upload_metadata'),
  mediaPayload('media_payload'),
  singleMemory('single_memory');

  const AnchorSyncBatchType(this.wireName);

  final String wireName;
}

class AnchorSyncBatchPayload {
  const AnchorSyncBatchPayload({
    required this.schemaVersion,
    required this.tenantRealm,
    required this.batchType,
    required this.endpointLabel,
    required this.generatedAt,
    required this.memories,
  });

  final int schemaVersion;
  final String tenantRealm;
  final AnchorSyncBatchType batchType;
  final String endpointLabel;
  final DateTime generatedAt;
  final List<AnchorSyncMemoryPayload> memories;

  int get itemCount => memories.length;

  int get mediaCount {
    return memories.where((memory) => memory.hasUploadableMedia).length;
  }

  String get payloadFingerprint {
    return _fingerprint(<String, Object?>{
      'schemaVersion': schemaVersion,
      'tenantRealm': tenantRealm,
      'batchType': batchType.wireName,
      'endpointLabel': endpointLabel,
      'memoryFingerprints': [
        for (final memory in memories) memory.payloadFingerprint,
      ],
    });
  }

  String get idempotencyKey {
    return 'batch_${_slug(tenantRealm)}_${batchType.wireName}_$payloadFingerprint';
  }

  String get idempotencyLabel {
    return 'Batch $payloadFingerprint';
  }

  String get summaryLabel {
    final itemLabel = itemCount == 1 ? 'item' : 'items';
    final mediaLabel = mediaCount == 1 ? 'media payload' : 'media payloads';
    return '$itemCount $itemLabel, $mediaCount $mediaLabel';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'tenantRealm': tenantRealm,
      'batchType': batchType.wireName,
      'idempotencyKey': idempotencyKey,
      'payloadFingerprint': payloadFingerprint,
      'endpointLabel': endpointLabel,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'summaryLabel': summaryLabel,
      'memories': [
        for (final memory in memories) memory.toJson(),
      ],
    };
  }
}

class AnchorSyncMemoryPayload {
  const AnchorSyncMemoryPayload({
    required this.clientMemoryId,
    required this.operation,
    required this.title,
    required this.caption,
    required this.capturedAt,
    required this.location,
    required this.captureMetadata,
    required this.privacy,
    required this.syncReason,
    this.media,
  });

  final String clientMemoryId;
  final String operation;
  final String title;
  final String caption;
  final DateTime? capturedAt;
  final AnchorSyncLocationPayload location;
  final AnchorSyncCaptureMetadataPayload captureMetadata;
  final AnchorSyncPrivacyPayload privacy;
  final String syncReason;
  final AnchorSyncMediaPayload? media;

  bool get hasMedia => media != null;

  bool get hasUploadableMedia => media?.requiresUpload ?? false;

  String get payloadFingerprint {
    return _fingerprint(<String, Object?>{
      'clientMemoryId': clientMemoryId,
      'operation': operation,
      'title': title,
      'caption': caption,
      'capturedAt': capturedAt?.toUtc().toIso8601String(),
      'location': location.toJson(),
      'captureMetadata': captureMetadata.toJson(),
      'privacy': privacy.toJson(),
      'syncReason': syncReason,
      'media': media?.toJson(),
    });
  }

  String get clientMutationId {
    return 'memory_${_slug(clientMemoryId)}_${operation}_$payloadFingerprint';
  }

  String get mutationLabel {
    return 'Mutation $payloadFingerprint';
  }

  String get operationLabel {
    return switch (operation) {
      'metadata_update' => 'Metadata payload',
      'create_memory' => 'Create memory payload',
      _ => 'Sync payload',
    };
  }

  String get visibilityLabel {
    return privacy.isPrivate ? 'Private payload' : 'Public payload';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'clientMemoryId': clientMemoryId,
      'clientMutationId': clientMutationId,
      'payloadFingerprint': payloadFingerprint,
      'operation': operation,
      'title': title,
      'caption': caption,
      'capturedAt': capturedAt?.toUtc().toIso8601String(),
      'location': location.toJson(),
      'captureMetadata': captureMetadata.toJson(),
      'privacy': privacy.toJson(),
      'syncReason': syncReason,
      'media': media?.toJson(),
    };
  }
}

class AnchorSyncLocationPayload {
  const AnchorSyncLocationPayload({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.accuracyMeters,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final double? altitudeMeters;
  final double? accuracyMeters;
  final String label;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'latitude': _finiteDouble(latitude),
      'longitude': _finiteDouble(longitude),
      'altitudeMeters': altitudeMeters,
      'accuracyMeters': accuracyMeters,
      'label': label,
    };
  }
}

class AnchorSyncCaptureMetadataPayload {
  const AnchorSyncCaptureMetadataPayload({
    required this.headingDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.anchorType,
    required this.captureSource,
    required this.correctionEastMeters,
    required this.correctionNorthMeters,
    required this.correctionUpMeters,
    required this.manualCorrectionSavedAt,
    required this.localAnchorId,
    required this.cloudAnchorId,
    required this.cloudAnchorExpiresAt,
  });

  final double? headingDegrees;
  final double? pitchDegrees;
  final double? rollDegrees;
  final String anchorType;
  final String captureSource;
  final double correctionEastMeters;
  final double correctionNorthMeters;
  final double correctionUpMeters;
  final DateTime? manualCorrectionSavedAt;
  final String? localAnchorId;
  final String? cloudAnchorId;
  final DateTime? cloudAnchorExpiresAt;

  bool get hasManualCorrection {
    return correctionEastMeters != 0 ||
        correctionNorthMeters != 0 ||
        correctionUpMeters != 0;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'headingDegrees': headingDegrees,
      'pitchDegrees': pitchDegrees,
      'rollDegrees': rollDegrees,
      'anchorType': anchorType,
      'captureSource': captureSource,
      'manualCorrection': <String, Object?>{
        'eastMeters': _finiteDouble(correctionEastMeters),
        'northMeters': _finiteDouble(correctionNorthMeters),
        'upMeters': _finiteDouble(correctionUpMeters),
        'savedAt': manualCorrectionSavedAt?.toUtc().toIso8601String(),
        'active': hasManualCorrection,
      },
      'anchorIds': <String, Object?>{
        'localAnchorId': localAnchorId,
        'cloudAnchorId': cloudAnchorId,
        'cloudAnchorExpiresAt': cloudAnchorExpiresAt?.toUtc().toIso8601String(),
      },
    };
  }
}

class AnchorSyncPrivacyPayload {
  const AnchorSyncPrivacyPayload({
    required this.isPrivate,
    required this.allowComments,
    required this.hasArExperience,
  });

  final bool isPrivate;
  final bool allowComments;
  final bool hasArExperience;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'isPrivate': isPrivate,
      'allowComments': allowComments,
      'hasArExperience': hasArExperience,
    };
  }
}

class AnchorSyncMediaPayload {
  const AnchorSyncMediaPayload({
    required this.type,
    required this.mediaId,
    required this.storagePath,
    required this.storedAt,
    required this.byteLength,
    required this.hasLocalPayload,
    required this.requiresUpload,
    required this.durationMs,
    required this.frameCount,
    required this.targetFps,
    required this.videoBitrateKbps,
    required this.outputFormat,
    required this.includesUIOverlay,
    required this.includesAudio,
    required this.fileSizeBytes,
    required this.recordingQualityReviewedAt,
    required this.arDiagnostics,
    this.modelAsset,
    this.modelValidation,
    this.modelRenderProfile,
  });

  final String type;
  final String? mediaId;
  final String? storagePath;
  final DateTime? storedAt;
  final int byteLength;
  final bool hasLocalPayload;
  final bool requiresUpload;
  final int? durationMs;
  final int? frameCount;
  final int? targetFps;
  final int? videoBitrateKbps;
  final String? outputFormat;
  final bool includesUIOverlay;
  final bool includesAudio;
  final int? fileSizeBytes;
  final DateTime? recordingQualityReviewedAt;
  final Map<String, Object?>? arDiagnostics;
  final Map<String, Object?>? modelAsset;
  final Map<String, Object?>? modelValidation;
  final Map<String, Object?>? modelRenderProfile;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'mediaId': mediaId,
      'storagePath': storagePath,
      'storedAt': storedAt?.toUtc().toIso8601String(),
      'byteLength': byteLength,
      'hasLocalPayload': hasLocalPayload,
      'requiresUpload': requiresUpload,
      'durationMs': durationMs,
      'frameCount': frameCount,
      'targetFps': targetFps,
      'videoBitrateKbps': videoBitrateKbps,
      'outputFormat': outputFormat,
      'includesUIOverlay': includesUIOverlay,
      'includesAudio': includesAudio,
      'fileSizeBytes': fileSizeBytes,
      'recordingQualityReviewedAt':
          recordingQualityReviewedAt?.toUtc().toIso8601String(),
      'arDiagnostics': arDiagnostics,
      'modelAsset': modelAsset,
      'modelValidation': modelValidation,
      'modelRenderProfile': modelRenderProfile,
    };
  }
}

class AnchorSyncPayloadBuilder {
  const AnchorSyncPayloadBuilder({required LocalFirstSyncRuntime runtime})
      : _runtime = runtime;

  final LocalFirstSyncRuntime _runtime;

  AnchorSyncBatchPayload batchPayload(
    Iterable<AnchorMemory> memories, {
    required AnchorSyncBatchType batchType,
    DateTime? generatedAt,
  }) {
    return AnchorSyncBatchPayload(
      schemaVersion: 1,
      tenantRealm: _runtime.tenantRealm,
      batchType: batchType,
      endpointLabel: _runtime.endpointLabel,
      generatedAt: generatedAt ?? DateTime.now(),
      memories: [
        for (final memory in memories) memoryPayload(memory),
      ],
    );
  }

  AnchorSyncMemoryPayload memoryPayload(AnchorMemory memory) {
    final metadata = memory.captureMetadata;
    return AnchorSyncMemoryPayload(
      clientMemoryId: memory.id,
      operation: _operationFor(memory.syncReason),
      title: memory.title,
      caption: memory.caption,
      capturedAt: memory.capturedAt,
      location: AnchorSyncLocationPayload(
        latitude: memory.latitude,
        longitude: memory.longitude,
        altitudeMeters: _finiteDouble(metadata.altitudeMeters),
        accuracyMeters: _finiteDouble(metadata.gpsAccuracyMeters),
        label: memory.locationLabel,
      ),
      captureMetadata: AnchorSyncCaptureMetadataPayload(
        headingDegrees: _finiteDouble(metadata.headingDegrees),
        pitchDegrees: _finiteDouble(metadata.pitchDegrees),
        rollDegrees: _finiteDouble(metadata.rollDegrees),
        anchorType: metadata.anchorType,
        captureSource: metadata.captureSource,
        correctionEastMeters: metadata.correctionEastMeters,
        correctionNorthMeters: metadata.correctionNorthMeters,
        correctionUpMeters: metadata.correctionUpMeters,
        manualCorrectionSavedAt: metadata.manualCorrectionSavedAt,
        localAnchorId: metadata.localAnchorId,
        cloudAnchorId: metadata.cloudAnchorId,
        cloudAnchorExpiresAt: metadata.cloudAnchorExpiresAt,
      ),
      privacy: AnchorSyncPrivacyPayload(
        isPrivate: memory.isPrivate,
        allowComments: memory.allowComments,
        hasArExperience: memory.hasArExperience,
      ),
      syncReason: memory.syncReason.name,
      media: _mediaPayload(memory.mediaAttachment),
    );
  }

  String _operationFor(AnchorSyncReason reason) {
    return switch (reason) {
      AnchorSyncReason.metadataUpdate => 'metadata_update',
      AnchorSyncReason.none || AnchorSyncReason.newCapture => 'create_memory',
    };
  }

  AnchorSyncMediaPayload? _mediaPayload(AnchorMediaAttachment? attachment) {
    if (attachment == null) {
      return null;
    }
    return AnchorSyncMediaPayload(
      type: attachment.type.name,
      mediaId: attachment.mediaId,
      storagePath: attachment.storagePath,
      storedAt: attachment.storedAt,
      byteLength: attachment.bytes?.lengthInBytes ?? 0,
      hasLocalPayload: attachment.hasLocalPayload,
      requiresUpload: attachment.hasUploadablePayload,
      durationMs: attachment.duration?.inMilliseconds,
      frameCount: attachment.frameCount,
      targetFps: attachment.targetFps,
      videoBitrateKbps: attachment.videoBitrateKbps,
      outputFormat: attachment.outputFormat,
      includesUIOverlay: attachment.includesUIOverlay,
      includesAudio: attachment.includesAudio,
      fileSizeBytes: attachment.fileSizeBytes,
      recordingQualityReviewedAt: attachment.recordingQualityReviewedAt,
      arDiagnostics: normalizedARCaptureDiagnosticsPayload(
        attachment.arDiagnostics,
      ),
      modelAsset: attachment.modelAsset?.toMap(),
      modelValidation: _modelValidationPayload(attachment),
      modelRenderProfile: _modelRenderProfilePayload(attachment),
    );
  }
}

Map<String, Object?>? _modelValidationPayload(
  AnchorMediaAttachment attachment,
) {
  final report = attachment.modelValidationReport;
  if (report == null) {
    return null;
  }
  return <String, Object?>{
    'target': report.target.name,
    'isValid': report.isValid,
    'hasWarnings': report.hasWarnings,
    'summaryLabel': report.summaryLabel,
    'issueLabels': report.issueLabels,
    'errorLabels': report.errorLabels,
    'warningLabels': report.warningLabels,
    'usesAndroidPrimitiveFallback': report.usesAndroidPrimitiveFallback,
  };
}

Map<String, Object?>? _modelRenderProfilePayload(
  AnchorMediaAttachment attachment,
) {
  final profile = attachment.modelRenderProfile;
  if (profile == null) {
    return null;
  }
  return profile.toMap();
}

double? _finiteDouble(double value) {
  return value.isFinite ? value : null;
}

String _fingerprint(Object? value) {
  final canonical = _canonicalize(value);
  var hash = 0x811c9dc5;
  for (final codeUnit in canonical.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _canonicalize(Object? value) {
  if (value is Map) {
    final entries = [
      for (final entry in value.entries)
        MapEntry(entry.key.toString(), entry.value),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return '{${[
      for (final entry in entries)
        '${jsonEncode(entry.key)}:${_canonicalize(entry.value)}',
    ].join(',')}}';
  }
  if (value is Iterable) {
    return '[${[
      for (final item in value) _canonicalize(item),
    ].join(',')}]';
  }
  if (value is DateTime) {
    return jsonEncode(value.toUtc().toIso8601String());
  }
  return jsonEncode(value);
}

String _slug(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}
