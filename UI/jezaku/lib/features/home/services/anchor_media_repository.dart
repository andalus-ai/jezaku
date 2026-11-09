import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/ar_capture_diagnostics_payload.dart';

final anchorMediaRepositoryRevisionProvider =
    NotifierProvider<AnchorMediaRepositoryRevision, int>(
  AnchorMediaRepositoryRevision.new,
);

class AnchorMediaRepositoryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}

final anchorMediaRepositoryProvider = Provider<AnchorMediaRepository>((ref) {
  return InMemoryAnchorMediaRepository(
    onChanged: () {
      ref.read(anchorMediaRepositoryRevisionProvider.notifier).bump();
    },
  );
});

abstract class AnchorMediaRepository {
  AnchorMediaAttachment storeAttachment(
    AnchorMediaAttachment attachment, {
    DateTime? storedAt,
  });

  AnchorStoredMedia? mediaById(String mediaId);

  List<AnchorStoredMedia> get allMedia;

  int get cachedByteLength;

  int get cachedMediaCount;

  bool markRecordingQualityReviewed(String mediaId, DateTime reviewedAt);

  bool removeMedia(String mediaId);

  int clearCachedMedia();

  AnchorMediaStorageReport inspectStorage();

  AnchorMediaStorageRepairResult repairStorage();
}

class InMemoryAnchorMediaRepository implements AnchorMediaRepository {
  InMemoryAnchorMediaRepository({void Function()? onChanged})
      : _onChanged = onChanged;

  final void Function()? _onChanged;
  final _mediaById = <String, AnchorStoredMedia>{};
  int _nextSequence = 1;

  @override
  List<AnchorStoredMedia> get allMedia {
    return List<AnchorStoredMedia>.unmodifiable(_mediaById.values);
  }

  @override
  int get cachedByteLength {
    return _mediaById.values.fold<int>(
      0,
      (total, media) => total + media.byteLength,
    );
  }

  @override
  int get cachedMediaCount => _mediaById.length;

  @override
  AnchorStoredMedia? mediaById(String mediaId) {
    return _mediaById[mediaId];
  }

  @override
  bool markRecordingQualityReviewed(String mediaId, DateTime reviewedAt) {
    final normalizedMediaId = mediaId.trim();
    final media = _mediaById[normalizedMediaId];
    if (media == null) {
      return false;
    }

    _mediaById[normalizedMediaId] =
        media.withRecordingQualityReviewedAt(reviewedAt);
    _onChanged?.call();
    return true;
  }

  @override
  AnchorMediaAttachment storeAttachment(
    AnchorMediaAttachment attachment, {
    DateTime? storedAt,
  }) {
    final existingId = attachment.mediaId;
    if (existingId != null && _mediaById.containsKey(existingId)) {
      return _mediaById[existingId]!.toAttachment();
    }

    final mediaId = existingId == null || existingId.trim().isEmpty
        ? _generateMediaId(attachment.type)
        : existingId;
    final storedMedia = AnchorStoredMedia(
      id: mediaId,
      type: attachment.type,
      storagePath: attachment.storagePath ?? 'jejaku://media/$mediaId',
      storedAt: storedAt ?? attachment.storedAt ?? DateTime.now(),
      bytes: attachment.bytes,
      sourceFilePath: attachment.filePath,
      duration: attachment.duration,
      frameCount: attachment.frameCount,
      targetFps: attachment.targetFps,
      videoBitrateKbps: attachment.videoBitrateKbps,
      outputFormat: attachment.outputFormat,
      includesUIOverlay: attachment.includesUIOverlay,
      includesAudio: attachment.includesAudio,
      fileSizeBytes: attachment.fileSizeBytes,
      recordingQualityReviewedAt: attachment.recordingQualityReviewedAt,
      arDiagnostics: attachment.arDiagnostics,
    );
    _mediaById[mediaId] = storedMedia;
    _onChanged?.call();
    return storedMedia.toAttachment();
  }

  @override
  bool removeMedia(String mediaId) {
    final removedMedia = _mediaById.remove(mediaId.trim());
    if (removedMedia == null) {
      return false;
    }
    _onChanged?.call();
    return true;
  }

  @override
  int clearCachedMedia() {
    final clearedCount = _mediaById.length;
    if (clearedCount == 0) {
      return 0;
    }
    _mediaById.clear();
    _onChanged?.call();
    return clearedCount;
  }

  @override
  AnchorMediaStorageReport inspectStorage() {
    return AnchorMediaStorageReport(
      backendLabel: 'In-memory media cache',
      cachedMediaCount: cachedMediaCount,
      cachedByteLength: cachedByteLength,
      trackedBlobFileCount: 0,
      orphanedBlobFileCount: 0,
      hasPersistentManifest: false,
      hasBackupManifest: false,
      hasTemporaryManifest: false,
      hasInvalidManifest: false,
    );
  }

  @override
  AnchorMediaStorageRepairResult repairStorage() {
    return const AnchorMediaStorageRepairResult(
      removedOrphanedBlobFileCount: 0,
      removedTemporaryManifest: false,
      removedBackupManifest: false,
      removedInvalidManifest: false,
      restoredBackupManifest: false,
      rebuiltManifest: false,
    );
  }

  String _generateMediaId(AnchorMediaType type) {
    final sequence = _nextSequence++;
    return 'media_${type.name}_${sequence.toString().padLeft(4, '0')}';
  }
}

class AnchorMediaStorageReport {
  const AnchorMediaStorageReport({
    required this.backendLabel,
    required this.cachedMediaCount,
    required this.cachedByteLength,
    required this.trackedBlobFileCount,
    required this.orphanedBlobFileCount,
    required this.hasPersistentManifest,
    required this.hasBackupManifest,
    required this.hasTemporaryManifest,
    required this.hasInvalidManifest,
  });

  final String backendLabel;
  final int cachedMediaCount;
  final int cachedByteLength;
  final int trackedBlobFileCount;
  final int orphanedBlobFileCount;
  final bool hasPersistentManifest;
  final bool hasBackupManifest;
  final bool hasTemporaryManifest;
  final bool hasInvalidManifest;

  bool get hasStorageWarnings {
    return orphanedBlobFileCount > 0 ||
        hasBackupManifest ||
        hasTemporaryManifest ||
        hasInvalidManifest;
  }

  List<String> get issueLabels {
    return [
      if (orphanedBlobFileCount == 1) '1 orphaned media file',
      if (orphanedBlobFileCount > 1)
        '$orphanedBlobFileCount orphaned media files',
      if (hasTemporaryManifest) 'temporary manifest pending',
      if (hasBackupManifest) 'backup manifest available',
      if (hasInvalidManifest) 'recovery manifest available',
    ];
  }

  String get statusLabel {
    if (!hasStorageWarnings) {
      return 'Storage healthy';
    }
    return issueLabels.join(', ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'backendLabel': backendLabel,
      'cachedMediaCount': cachedMediaCount,
      'cachedByteLength': cachedByteLength,
      'trackedBlobFileCount': trackedBlobFileCount,
      'orphanedBlobFileCount': orphanedBlobFileCount,
      'hasPersistentManifest': hasPersistentManifest,
      'hasBackupManifest': hasBackupManifest,
      'hasTemporaryManifest': hasTemporaryManifest,
      'hasInvalidManifest': hasInvalidManifest,
      'hasStorageWarnings': hasStorageWarnings,
      'statusLabel': statusLabel,
      'issueLabels': issueLabels,
    };
  }
}

class AnchorMediaStorageRepairResult {
  const AnchorMediaStorageRepairResult({
    required this.removedOrphanedBlobFileCount,
    required this.removedTemporaryManifest,
    required this.removedBackupManifest,
    required this.removedInvalidManifest,
    required this.restoredBackupManifest,
    required this.rebuiltManifest,
  });

  final int removedOrphanedBlobFileCount;
  final bool removedTemporaryManifest;
  final bool removedBackupManifest;
  final bool removedInvalidManifest;
  final bool restoredBackupManifest;
  final bool rebuiltManifest;

  bool get repairedAny {
    return removedOrphanedBlobFileCount > 0 ||
        removedTemporaryManifest ||
        removedBackupManifest ||
        removedInvalidManifest ||
        restoredBackupManifest ||
        rebuiltManifest;
  }

  List<String> get actionLabels {
    return [
      if (removedOrphanedBlobFileCount == 1) 'removed 1 orphaned media file',
      if (removedOrphanedBlobFileCount > 1)
        'removed $removedOrphanedBlobFileCount orphaned media files',
      if (removedTemporaryManifest) 'cleared temporary manifest',
      if (removedBackupManifest) 'cleared backup manifest',
      if (removedInvalidManifest) 'cleared recovery manifest',
      if (restoredBackupManifest) 'restored backup manifest',
      if (rebuiltManifest) 'rebuilt manifest',
    ];
  }

  String get summaryLabel {
    if (!repairedAny) {
      return 'Media storage already healthy.';
    }
    return actionLabels.join(', ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'removedOrphanedBlobFileCount': removedOrphanedBlobFileCount,
      'removedTemporaryManifest': removedTemporaryManifest,
      'removedBackupManifest': removedBackupManifest,
      'removedInvalidManifest': removedInvalidManifest,
      'restoredBackupManifest': restoredBackupManifest,
      'rebuiltManifest': rebuiltManifest,
      'repairedAny': repairedAny,
      'summaryLabel': summaryLabel,
      'actionLabels': actionLabels,
    };
  }
}

class AnchorStoredMedia {
  AnchorStoredMedia({
    required this.id,
    required this.type,
    required this.storagePath,
    required this.storedAt,
    Uint8List? bytes,
    this.sourceFilePath,
    this.duration,
    this.frameCount,
    this.targetFps,
    this.videoBitrateKbps,
    this.outputFormat,
    this.includesUIOverlay = true,
    this.includesAudio = false,
    this.fileSizeBytes,
    this.recordingQualityReviewedAt,
    Map<String, Object?>? arDiagnostics,
  })  : _bytes = bytes == null ? null : Uint8List.fromList(bytes),
        arDiagnostics = normalizedARCaptureDiagnosticsPayload(arDiagnostics);

  final String id;
  final AnchorMediaType type;
  final String storagePath;
  final DateTime storedAt;
  final Uint8List? _bytes;
  final String? sourceFilePath;
  final Duration? duration;
  final int? frameCount;
  final int? targetFps;
  final int? videoBitrateKbps;
  final String? outputFormat;
  final bool includesUIOverlay;
  final bool includesAudio;
  final int? fileSizeBytes;
  final DateTime? recordingQualityReviewedAt;
  final Map<String, Object?>? arDiagnostics;

  Uint8List? get bytes {
    final bytes = _bytes;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  int get byteLength => _bytes?.lengthInBytes ?? 0;

  bool get hasBytes => _bytes != null;

  bool get hasSourceFile =>
      sourceFilePath != null && sourceFilePath!.isNotEmpty;

  AnchorMediaAttachment toAttachment() {
    return AnchorMediaAttachment(
      mediaId: id,
      type: type,
      storagePath: storagePath,
      storedAt: storedAt,
      bytes: bytes,
      filePath: sourceFilePath,
      duration: duration,
      frameCount: frameCount,
      targetFps: targetFps,
      videoBitrateKbps: videoBitrateKbps,
      outputFormat: outputFormat,
      includesUIOverlay: includesUIOverlay,
      includesAudio: includesAudio,
      fileSizeBytes: fileSizeBytes,
      recordingQualityReviewedAt: recordingQualityReviewedAt,
      arDiagnostics: arDiagnostics,
    );
  }

  AnchorStoredMedia withRecordingQualityReviewedAt(DateTime reviewedAt) {
    return AnchorStoredMedia(
      id: id,
      type: type,
      storagePath: storagePath,
      storedAt: storedAt,
      bytes: bytes,
      sourceFilePath: sourceFilePath,
      duration: duration,
      frameCount: frameCount,
      targetFps: targetFps,
      videoBitrateKbps: videoBitrateKbps,
      outputFormat: outputFormat,
      includesUIOverlay: includesUIOverlay,
      includesAudio: includesAudio,
      fileSizeBytes: fileSizeBytes,
      recordingQualityReviewedAt: reviewedAt.toUtc(),
      arDiagnostics: arDiagnostics,
    );
  }
}
